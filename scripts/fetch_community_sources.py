#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
社区书源抓取 + 过滤 + 合并工具。

从 legado 社区书源聚合站（legado.aoaostar.com）拉取多个书源集合，
过滤掉本项目不支持的源（依赖 JS 网络/Java 桥接/音频源等），
去重后输出为 legado 格式 JSON，供 App 远程拉取。

用法:
    python3 scripts/fetch_community_sources.py

输出:
    book_sources/community_sources.json

过滤规则:
    1. 丢弃 bookSourceType != 0（音频源，本项目搜索聚合不支持）
    2. 丢弃依赖 java.ajax/get/post/JavaImporter 等 Java 桥接的源
       （本项目用 flutter_js，无 Java 桥接能力）
    3. 丢弃 searchUrl 为空或复杂 @js 规则（含 function/try/for）的源
       （SearchUrlParser 只支持静态 URL 提取）
    4. 丢弃 ruleSearch.bookList 或 ruleContent.content 为空的源
       （缺少核心规则无法工作）
    5. 按 bookSourceUrl 去重，同 URL 保留书源名更短的（通常更简洁）
"""

import json
import os
import re
import sys
import time

try:
    import urllib.request
except ImportError:
    print("需要 Python 3 标准库", file=sys.stderr)
    sys.exit(1)

# 社区书源集合（legado.aoaostar.com 聚合站）
# 每个集合是独立维护的书源列表，取并集后去重
COMMUNITY_SOURCE_SETS = [
    {
        "name": "破冰书源",
        "url": "https://legado.aoaostar.com/sources/4dc410d1.json",
    },
    {
        "name": "关耳女频",
        "url": "https://legado.aoaostar.com/sources/e3e5d620.json",
    },
    {
        "name": "XIU2精品",
        "url": "https://legado.aoaostar.com/sources/71e56d4f.json",
    },
]

# flutter_js 无法实现的 Java 桥接方法（出现即丢弃该源）
JAVA_BRIDGE_PATTERNS = [
    "java.ajax",
    "java.get(",
    "java.post(",
    "java.getString(",
    "java.put(",
    "JavaImporter",
    "java.startBrowser",
    "java.getVerification",
    "java.setContent",
    "java.getElement",
    "java.getCookie",
    "java.removeCookie",
    "java.log(",
    "java.toast(",
]

# 项目根目录
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_PATH = os.path.join(PROJECT_ROOT, "book_sources", "community_sources.json")


def fetch_json(url, timeout=60):
    """拉取 JSON 并解析。"""
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        data = resp.read()
        return json.loads(data.decode("utf-8"))


def is_source_supported(source):
    """
    判断书源是否被本项目支持。

    返回 (True, '') 或 (False, '原因')。
    """
    blob = json.dumps(source, ensure_ascii=False)

    # 1. 音频源不支持（搜索聚合按文本源处理）
    if source.get("bookSourceType", 0) != 0:
        return False, "音频源(type!=0)"

    # 2. 依赖 Java 桥接方法
    for pattern in JAVA_BRIDGE_PATTERNS:
        if pattern in blob:
            return False, f"依赖Java桥接({pattern})"

    # 3. searchUrl 检查
    search_url = (source.get("searchUrl") or "").strip()
    if not search_url:
        return False, "searchUrl为空"

    # 复杂 @js 规则（含 function/try/for 等真实逻辑）不支持
    if search_url.startswith("@js:") or search_url.startswith("<js>"):
        if any(kw in search_url for kw in ["function", "try", "for(", "while("]):
            return False, "复杂@js searchUrl"

    # 4. 核心规则完整性
    rule_search = source.get("ruleSearch") or {}
    if not rule_search.get("bookList"):
        return False, "ruleSearch.bookList为空"

    rule_content = source.get("ruleContent") or {}
    if not rule_content.get("content"):
        return False, "ruleContent.content为空"

    # 5. header 字段若是 @js/<js> 格式，请求时不带 header，可能导致反爬
    #    但不直接丢弃，标记为可能受限（降级处理）

    return True, ""


def normalize_source(source):
    """
    精简书源 JSON：去掉本项目用不到的字段，减小体积。

    保留 legado 核心字段，丢弃评论、探索页等非搜索必需字段。
    """
    keep_fields = [
        "bookSourceName",
        "bookSourceUrl",
        "bookSourceType",
        "enabled",
        "bookSourceGroup",
        "searchUrl",
        "loginUrl",
        "ruleSearch",
        "ruleBookInfo",
        "ruleToc",
        "ruleContent",
        "header",
    ]
    result = {}
    for f in keep_fields:
        if f in source:
            result[f] = source[f]
    # 确保 enabled 为 true（社区源可能默认 false）
    result["enabled"] = True
    # 确保 type 为 0
    result["bookSourceType"] = 0
    return result


def main():
    print("=" * 60)
    print("社区书源抓取 + 过滤工具")
    print("=" * 60)

    all_sources = {}  # key=bookSourceUrl, value=(name_len, source)

    for src_set in COMMUNITY_SOURCE_SETS:
        name = src_set["name"]
        url = src_set["url"]
        print(f"\n[{name}] 拉取中: {url}")
        try:
            raw_list = fetch_json(url)
            print(f"  拉取成功: {len(raw_list)} 条原始书源")
        except Exception as e:
            print(f"  ✗ 拉取失败: {e}")
            continue

        kept = 0
        dropped = 0
        drop_reasons = {}

        for s in raw_list:
            ok, reason = is_source_supported(s)
            if not ok:
                dropped += 1
                drop_reasons[reason] = drop_reasons.get(reason, 0) + 1
                continue

            normalized = normalize_source(s)
            src_url = normalized["bookSourceUrl"]

            # 去重：同 URL 保留书源名更短的
            name_len = len(normalized.get("bookSourceName", ""))
            if src_url in all_sources:
                if name_len < all_sources[src_url][0]:
                    all_sources[src_url] = (name_len, normalized)
            else:
                all_sources[src_url] = (name_len, normalized)
                kept += 1

        print(f"  过滤后保留: {kept} 条")
        print(f"  丢弃: {dropped} 条")
        if drop_reasons:
            for reason, count in sorted(drop_reasons.items(), key=lambda x: -x[1]):
                print(f"    - {reason}: {count} 条")

    # 输出
    final = [v[1] for v in all_sources.values()]
    # 按书源名排序，方便查看
    final.sort(key=lambda s: s.get("bookSourceName", ""))

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(final, f, ensure_ascii=False, indent=2)

    print("\n" + "=" * 60)
    print(f"输出: {OUTPUT_PATH}")
    print(f"最终书源数: {len(final)} 条")
    print("=" * 60)

    # 打印书源名列表
    print("\n书源列表:")
    for i, s in enumerate(final, 1):
        print(f"  {i:3d}. {s.get('bookSourceName', '?')} ({s.get('bookSourceUrl', '?')})")


if __name__ == "__main__":
    main()
