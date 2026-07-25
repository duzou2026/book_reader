import 'package:book_reader/app/providers.dart';
import 'package:book_reader/data/models/book_source.dart';
import 'package:book_reader/services/book_info/content_purifier.dart';
import 'package:book_reader/ui/common/theme_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 书源编辑页：可视化编辑 [BookSource] 的所有字段。
///
/// 通过 Tab 切换 5 个区域：基本信息 / 搜索规则 / 详情规则 / 目录规则 / 正文规则。
/// 入口：书源管理页的「编辑」按钮，或「新建书源」入口。
class BookSourceEditPage extends ConsumerStatefulWidget {
  /// 待编辑的书源；为 null 表示新建。
  final BookSource? initial;

  const BookSourceEditPage({super.key, this.initial});

  @override
  ConsumerState<BookSourceEditPage> createState() => _BookSourceEditPageState();
}

class _BookSourceEditPageState extends ConsumerState<BookSourceEditPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // 基本信息字段
  late final _nameCtrl = TextEditingController(text: widget.initial?.bookSourceName ?? '');
  late final _urlCtrl = TextEditingController(text: widget.initial?.bookSourceUrl ?? '');
  late final _groupCtrl = TextEditingController(text: widget.initial?.bookSourceGroup ?? '');
  late final _searchUrlCtrl = TextEditingController(text: widget.initial?.searchUrl ?? '');
  late final _loginUrlCtrl = TextEditingController(text: widget.initial?.loginUrl ?? '');
  late final _priorityCtrl = TextEditingController(text: '${widget.initial?.priority ?? 0}');
  late final _weightCtrl = TextEditingController(text: '${widget.initial?.weight ?? 0}');
  late BookSourceType _type = widget.initial?.bookSourceType ?? BookSourceType.text;
  late bool _enabled = widget.initial?.enabled ?? true;

  // 搜索规则字段
  late final _rsBookList = TextEditingController(text: widget.initial?.ruleSearch?.bookList ?? '');
  late final _rsName = TextEditingController(text: widget.initial?.ruleSearch?.name ?? '');
  late final _rsAuthor = TextEditingController(text: widget.initial?.ruleSearch?.author ?? '');
  late final _rsKind = TextEditingController(text: widget.initial?.ruleSearch?.kind ?? '');
  late final _rsWordCount = TextEditingController(text: widget.initial?.ruleSearch?.wordCount ?? '');
  late final _rsLastChapter = TextEditingController(text: widget.initial?.ruleSearch?.lastChapter ?? '');
  late final _rsIntro = TextEditingController(text: widget.initial?.ruleSearch?.intro ?? '');
  late final _rsCoverUrl = TextEditingController(text: widget.initial?.ruleSearch?.coverUrl ?? '');
  late final _rsBookUrl = TextEditingController(text: widget.initial?.ruleSearch?.bookUrl ?? '');

  // 详情规则字段
  late final _rbiName = TextEditingController(text: widget.initial?.ruleBookInfo?.name ?? '');
  late final _rbiAuthor = TextEditingController(text: widget.initial?.ruleBookInfo?.author ?? '');
  late final _rbiIntro = TextEditingController(text: widget.initial?.ruleBookInfo?.intro ?? '');
  late final _rbiCoverUrl = TextEditingController(text: widget.initial?.ruleBookInfo?.coverUrl ?? '');
  late final _rbiKind = TextEditingController(text: widget.initial?.ruleBookInfo?.kind ?? '');
  late final _rbiLastChapter = TextEditingController(text: widget.initial?.ruleBookInfo?.lastChapter ?? '');
  late final _rbiTocUrl = TextEditingController(text: widget.initial?.ruleBookInfo?.tocUrl ?? '');
  late final _rbiWordCount = TextEditingController(text: widget.initial?.ruleBookInfo?.wordCount ?? '');

  // 目录规则字段
  late final _rtChapterList = TextEditingController(text: widget.initial?.ruleToc?.chapterList ?? '');
  late final _rtChapterName = TextEditingController(text: widget.initial?.ruleToc?.chapterName ?? '');
  late final _rtChapterUrl = TextEditingController(text: widget.initial?.ruleToc?.chapterUrl ?? '');
  late final _rtNextTocUrl = TextEditingController(text: widget.initial?.ruleToc?.nextTocUrl ?? '');
  late final _rtIsVolume = TextEditingController(text: widget.initial?.ruleToc?.isVolume ?? '');
  late final _rtIsVip = TextEditingController(text: widget.initial?.ruleToc?.isVip ?? '');
  late final _rtUpdateTime = TextEditingController(text: widget.initial?.ruleToc?.updateTime ?? '');

  // 正文规则字段
  late final _rcContent = TextEditingController(text: widget.initial?.ruleContent?.content ?? '');
  late final _rcNextContentUrl = TextEditingController(text: widget.initial?.ruleContent?.nextContentUrl ?? '');
  late final _rcReplaceRegex = TextEditingController(text: widget.initial?.ruleContent?.replaceRegex ?? '');
  late final _rcImageStyle = TextEditingController(text: widget.initial?.ruleContent?.imageStyle ?? '');

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in [
      _nameCtrl, _urlCtrl, _groupCtrl, _searchUrlCtrl, _loginUrlCtrl,
      _priorityCtrl, _weightCtrl,
      _rsBookList, _rsName, _rsAuthor, _rsKind, _rsWordCount,
      _rsLastChapter, _rsIntro, _rsCoverUrl, _rsBookUrl,
      _rbiName, _rbiAuthor, _rbiIntro, _rbiCoverUrl, _rbiKind,
      _rbiLastChapter, _rbiTocUrl, _rbiWordCount,
      _rtChapterList, _rtChapterName, _rtChapterUrl, _rtNextTocUrl,
      _rtIsVolume, _rtIsVip, _rtUpdateTime,
      _rcContent, _rcNextContentUrl, _rcReplaceRegex, _rcImageStyle,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final url = _urlCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '书源名称不能为空');
      return;
    }
    if (url.isEmpty) {
      setState(() => _error = '书源 URL 不能为空');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final priority = int.tryParse(_priorityCtrl.text.trim()) ?? 0;
      final weight = int.tryParse(_weightCtrl.text.trim()) ?? 0;
      final source = BookSource(
        bookSourceName: name,
        bookSourceUrl: url,
        bookSourceType: _type,
        enabled: _enabled,
        bookSourceGroup: _groupCtrl.text.trim().isEmpty
            ? null
            : _groupCtrl.text.trim(),
        searchUrl: _searchUrlCtrl.text.trim().isEmpty
            ? null
            : _searchUrlCtrl.text.trim(),
        loginUrl: _loginUrlCtrl.text.trim().isEmpty
            ? null
            : _loginUrlCtrl.text.trim(),
        ruleSearch: RuleSearch(
          bookList: _empty(_rsBookList.text),
          name: _empty(_rsName.text),
          author: _empty(_rsAuthor.text),
          kind: _empty(_rsKind.text),
          wordCount: _empty(_rsWordCount.text),
          lastChapter: _empty(_rsLastChapter.text),
          intro: _empty(_rsIntro.text),
          coverUrl: _empty(_rsCoverUrl.text),
          bookUrl: _empty(_rsBookUrl.text),
        ),
        ruleBookInfo: RuleBookInfo(
          name: _empty(_rbiName.text),
          author: _empty(_rbiAuthor.text),
          intro: _empty(_rbiIntro.text),
          coverUrl: _empty(_rbiCoverUrl.text),
          kind: _empty(_rbiKind.text),
          lastChapter: _empty(_rbiLastChapter.text),
          tocUrl: _empty(_rbiTocUrl.text),
          wordCount: _empty(_rbiWordCount.text),
        ),
        ruleToc: RuleToc(
          chapterList: _empty(_rtChapterList.text),
          chapterName: _empty(_rtChapterName.text),
          chapterUrl: _empty(_rtChapterUrl.text),
          nextTocUrl: _empty(_rtNextTocUrl.text),
          isVolume: _empty(_rtIsVolume.text),
          isVip: _empty(_rtIsVip.text),
          updateTime: _empty(_rtUpdateTime.text),
        ),
        ruleContent: RuleContent(
          content: _empty(_rcContent.text),
          nextContentUrl: _empty(_rcNextContentUrl.text),
          replaceRegex: _empty(_rcReplaceRegex.text),
          imageStyle: _empty(_rcImageStyle.text),
        ),
        priority: priority,
        weight: weight,
      );
      await ref.read(bookSourceRepositoryProvider).upsert(source);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _empty(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.initial == null;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(isNew ? '新建书源' : '编辑书源'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('保存'),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '基本信息'),
            Tab(text: '搜索规则'),
            Tab(text: '详情规则'),
            Tab(text: '目录规则'),
            Tab(text: '正文规则'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              color: ThemeColors.errorContainer(context),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _error = null),
                  ),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBasicTab(),
                _buildSearchTab(),
                _buildBookInfoTab(),
                _buildTocTab(),
                _buildContentTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _TextField(label: '书源名称 *', controller: _nameCtrl, hint: '如：笔趣阁'),
        _TextField(label: '书源 URL *', controller: _urlCtrl, hint: 'https://www.biquge.com'),
        _TextField(label: '书源分组', controller: _groupCtrl, hint: '如：默认、中文、有声'),
        _TextField(
            label: '搜索 URL',
            controller: _searchUrlCtrl,
            hint: '支持 {{key}} 占位符，如 https://x.com/search?q={{key}}',
            maxLines: 2),
        _TextField(
            label: '登录 URL',
            controller: _loginUrlCtrl,
            hint: '可选，部分源需要登录才能搜索/阅读'),
        Row(
          children: [
            Expanded(child: _TextField(label: '优先级', controller: _priorityCtrl, hint: '0', keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: _TextField(label: '权重', controller: _weightCtrl, hint: '0', keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('类型：', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('文本'),
              selected: _type == BookSourceType.text,
              onSelected: (_) => setState(() => _type = BookSourceType.text),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('有声'),
              selected: _type == BookSourceType.audio,
              onSelected: (_) => setState(() => _type = BookSourceType.audio),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('启用'),
          value: _enabled,
          onChanged: (v) => setState(() => _enabled = v),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ThemeColors.infoContainer(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16),
                  SizedBox(width: 6),
                  Text('规则语法提示',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
              SizedBox(height: 6),
              Text(
                '• CSS 选择器：class.items@text\n'
                '• JSON Path：\$.name\n'
                '• 正则：re(pattern, group)\n'
                '• 多规则合并：a||b（前为空则取后）\n'
                '• 详情/目录 URL 拼接：可用 @css: 等前缀',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _TextField(label: '书籍列表', controller: _rsBookList, hint: 'class.book-item', maxLines: 2),
        _TextField(label: '书名', controller: _rsName, hint: 'tag.a@text'),
        _TextField(label: '作者', controller: _rsAuthor, hint: 'class.author@text'),
        _TextField(label: '分类', controller: _rsKind, hint: '可选'),
        _TextField(label: '字数', controller: _rsWordCount, hint: '可选'),
        _TextField(label: '最新章节', controller: _rsLastChapter, hint: '可选'),
        _TextField(label: '简介', controller: _rsIntro, hint: '可选', maxLines: 2),
        _TextField(label: '封面 URL', controller: _rsCoverUrl, hint: '可选'),
        _TextField(label: '书籍 URL', controller: _rsBookUrl, hint: 'tag.a@href'),
      ],
    );
  }

  Widget _buildBookInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _TextField(label: '书名', controller: _rbiName, hint: '可选，默认用搜索结果'),
        _TextField(label: '作者', controller: _rbiAuthor, hint: '可选'),
        _TextField(label: '简介', controller: _rbiIntro, hint: '可选', maxLines: 3),
        _TextField(label: '封面 URL', controller: _rbiCoverUrl, hint: '可选'),
        _TextField(label: '分类', controller: _rbiKind, hint: '可选'),
        _TextField(label: '最新章节', controller: _rbiLastChapter, hint: '可选'),
        _TextField(label: '目录 URL', controller: _rbiTocUrl, hint: '可选，不填则用书籍 URL'),
        _TextField(label: '字数', controller: _rbiWordCount, hint: '可选'),
      ],
    );
  }

  Widget _buildTocTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _TextField(label: '章节列表', controller: _rtChapterList, hint: 'class.chapter-item', maxLines: 2),
        _TextField(label: '章节名', controller: _rtChapterName, hint: 'tag.a@text'),
        _TextField(label: '章节 URL', controller: _rtChapterUrl, hint: 'tag.a@href'),
        _TextField(label: '下一页 URL', controller: _rtNextTocUrl, hint: '可选，分页目录用'),
        _TextField(label: '是否卷标', controller: _rtIsVolume, hint: '可选'),
        _TextField(label: '是否 VIP', controller: _rtIsVip, hint: '可选'),
        _TextField(label: '更新时间', controller: _rtUpdateTime, hint: '可选'),
      ],
    );
  }

  Widget _buildContentTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _TextField(label: '正文', controller: _rcContent, hint: 'class.content@html', maxLines: 3),
        _TextField(label: '下一页 URL', controller: _rcNextContentUrl, hint: '可选，长章节分页用'),
        _PurifyRulesField(controller: _rcReplaceRegex),
        const SizedBox(height: 12),
        _TextField(label: '图片样式', controller: _rcImageStyle, hint: '可选，如 full'),
      ],
    );
  }
}

class _TextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;

  const _TextField({
    required this.label,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

/// 净化规则字段：多行编辑 + 实时校验 + 测试按钮。
class _PurifyRulesField extends StatefulWidget {
  final TextEditingController controller;
  const _PurifyRulesField({required this.controller});

  @override
  State<_PurifyRulesField> createState() => _PurifyRulesFieldState();
}

class _PurifyRulesFieldState extends State<_PurifyRulesField> {
  PurifyValidateResult? _result;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_revalidate);
    _revalidate();
  }

  void _revalidate() {
    final r = ContentPurifier.validate(widget.controller.text);
    if (!mounted) return;
    setState(() => _result = r);
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('净化规则',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              if (r != null && r.ruleCount > 0)
                _Badge(
                  text: '${r.ruleCount} 条',
                  color: r.isValid ? Colors.green : Colors.orange,
                ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.science_outlined, size: 16),
                label: const Text('测试', style: TextStyle(fontSize: 12)),
                onPressed: _openTestDialog,
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: widget.controller,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              isDense: true,
              hintText: '一行一条规则，或用 || 分隔\n格式：regex 或 regex##replacement',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
          if (r != null && r.ruleCount > 0 && !r.isValid) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ThemeColors.errorContainer(context),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: ThemeColors.errorBorder(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in r.errors.take(3))
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(e,
                              style: TextStyle(
                                  color: ThemeColors.errorText(context), fontSize: 11)),
                        ),
                      ],
                    ),
                  if (r.errors.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(left: 18, top: 2),
                      child: Text('…还有 ${r.errors.length - 3} 条错误',
                          style: TextStyle(
                              color: ThemeColors.errorText(context), fontSize: 11)),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ThemeColors.infoContainer(context),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('语法提示',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
                SizedBox(height: 4),
                Text(
                  '• regex → 删除匹配内容\n'
                  '• regex##replacement → 替换为 replacement\n'
                  '• 多条规则用换行或 || 分隔\n'
                  '• 捕获组引用：\$1、\${1}、\$<name>\n'
                  '• 前缀 flag：(?i) 大小写不敏感、(?m) 多行、(?s) . 匹配换行',
                  style: TextStyle(fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openTestDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => _PurifyTestDialog(
        rules: widget.controller.text,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}

/// 净化规则测试对话框：输入示例文本，实时显示净化后的结果。
class _PurifyTestDialog extends StatefulWidget {
  final String rules;
  const _PurifyTestDialog({required this.rules});

  @override
  State<_PurifyTestDialog> createState() => _PurifyTestDialogState();
}

class _PurifyTestDialogState extends State<_PurifyTestDialog> {
  final _inputCtrl = TextEditingController(
    text: '请访问 m.example.com 看完整内容\n本章正文第一段。\n广告：xxx推广\n本章正文第二段。',
  );

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final input = _inputCtrl.text;
    final output = widget.rules.isEmpty
        ? input
        : ContentPurifier.purify(input, widget.rules);
    return AlertDialog(
      title: const Text('净化规则测试', style: TextStyle(fontSize: 16)),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('输入文本',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            TextField(
              controller: _inputCtrl,
              maxLines: 5,
              minLines: 3,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            const Text('净化后',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ThemeColors.successContainer(context),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: ThemeColors.successBorder(context)),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  output,
                  style: const TextStyle(
                      fontSize: 12, height: 1.4, fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
