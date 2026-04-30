import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:money_vibe/providers/account_provider.dart';
import 'package:money_vibe/providers/llm_provider.dart';
import 'package:money_vibe/providers/settings_provider.dart';
import 'package:money_vibe/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PortfolioAnalyzeScreen extends StatefulWidget {
  final String accountId;

  const PortfolioAnalyzeScreen({super.key, required this.accountId});

  @override
  State<PortfolioAnalyzeScreen> createState() => _PortfolioAnalyzeScreenState();
}

class _PortfolioAnalyzeScreenState extends State<PortfolioAnalyzeScreen> {
  late final supabase = Supabase.instance.client;

  String _holdingsData = '';
  bool _isStarted = false;
  bool _isLoading = false;
  bool _showScrollToBottom = false;

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initHoldingsData();
    _restoreOldMessages();
    _checkScrollPosition();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _checkScrollPosition() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollToBottom();
      }
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent) {
        if (_showScrollToBottom != false) {
          setState(() => _showScrollToBottom = false);
        }
      } else {
        if (_showScrollToBottom != true) {
          setState(() => _showScrollToBottom = true);
        }
      }
    });
  }

  void _restoreOldMessages() async {
    // check old messages
    final oldMessages = context.read<LlmProvider>().messages;
    if (oldMessages.isNotEmpty) {
      setState(() => _isStarted = true);
    }
  }

  void _initHoldingsData() {
    final provider = context.read<AccountProvider>();
    final holdings = provider.getHoldings(widget.accountId);

    _holdingsData = holdings
        .map(
          (h) =>
              """
                - ${h.ticker}
                จำนวนหุ้น: ${h.shares}
                ราคาปัจจุบัน: ${h.priceUsd.toStringAsFixed(2)}
                ต้นทุนต่อหุ้น: ${h.costBasisUsd.toStringAsFixed(2)}
                ต้นทุนรวม: ${h.totalCostUsd.toStringAsFixed(2)}
                มูลค่ารวม: ${h.valueUsd.toStringAsFixed(2)}
                กำไร/ขาดทุน: ${h.unrealizedPnlUsd.toStringAsFixed(2)} (${h.unrealizedPnlPct.toStringAsFixed(2)}%)
            
              """,
        )
        .join('\n');
  }

  void _initAnalysis() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendMessage('วิเคราะห์พอร์ตโฟลิโอ และ ให้คำแนะนำในการลงทุน');
    });
  }

  Future<void> _sendMessage(String text) async {
    if (!_isStarted) {
      setState(() => _isStarted = true);
    }

    final trimmed = text.trim();
    if (trimmed.isEmpty || _isLoading) return;

    setState(() {
      context.read<LlmProvider>().addMessage(role: 'user', content: trimmed);
      _isLoading = true;
    });
    _inputController.clear();
    _scrollToBottom();

    final llmApiKey = context.read<SettingsProvider>().llmApiKey;
    final llmBaseUrl = context.read<SettingsProvider>().llmBaseUrl;
    final llmModel = context.read<SettingsProvider>().llmModel;

    if (llmApiKey == null || llmBaseUrl == null || llmModel == null) {
      setState(() {
        context.read<LlmProvider>().addMessage(
          role: 'assistant',
          content:
              'กรุณาตั้งค่า LLM API Key, Base URL และ Model ในหน้าการตั้งค่าก่อนใช้งานฟีเจอร์นี้',
        );
        _isLoading = false;
      });
      return;
    }

    try {
      _scrollToBottom();

      final res = await supabase.functions.invoke(
        'llm-portfolio-analyze',
        body: {
          'apiKey': llmApiKey,
          'baseUrl': llmBaseUrl,
          'model': llmModel,
          'holdingsData': _holdingsData,
          'messages': context
              .read<LlmProvider>()
              .messages
              .map((m) => {'role': m.role, 'content': m.content})
              .toList(),
        },
      );
      final data = res.data;
      final content =
          (data['reply']['content'] as String?) ?? 'ไม่พบผลการวิเคราะห์';

      setState(() {
        context.read<LlmProvider>().limitMessages(10);

        context.read<LlmProvider>().addMessage(
          role: 'assistant',
          content: content,
        );

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        context.read<LlmProvider>().addMessage(
          role: 'assistant',
          content: 'เกิดข้อผิดพลาดในการเรียกฟังก์ชัน: $e',
        );

        _isLoading = false;
      });
      debugPrint('Error calling function: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
    final bgColor = isDarkMode
        ? AppColors.darkBackground
        : AppColors.background;
    final surfaceColor = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final textPrimary = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final textSecondary = isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = isDarkMode ? AppColors.darkDivider : AppColors.divider;

    final hasContent =
        _isStarted || context.read<LlmProvider>().messages.isNotEmpty;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('วิเคราะห์ Portfoilo ด้วย AI'),
        backgroundColor: isDarkMode ? AppColors.darkHeader : AppColors.header,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _isStarted = false;
                _showScrollToBottom = false;
              });
              context.read<LlmProvider>().clearMessages();
            },
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: 'เริ่มใหม่',
          ),
        ],
      ),
      body: Consumer<LlmProvider>(
        builder: (context, llmProvider, child) {
          return SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    hasContent
                        ? Expanded(
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                              itemCount:
                                  llmProvider.messages.length +
                                  (_isLoading ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == llmProvider.messages.length) {
                                  return _LoadingBubble(
                                    isDarkMode: isDarkMode,
                                    surfaceColor: surfaceColor,
                                    textSecondary: textSecondary,
                                  );
                                }
                                return _MessageBubble(
                                  // message: llmProvider.messages[index],
                                  message: llmProvider.messages[index],
                                  isDarkMode: isDarkMode,
                                  surfaceColor: surfaceColor,
                                  textPrimary: textPrimary,
                                );
                              },
                            ),
                          )
                        : Expanded(
                            child: Center(
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() => _isStarted = true);
                                  _initAnalysis();
                                },
                                child: const Text('เริ่มต้นการวิเคราะห์'),
                              ),
                            ),
                          ),
                    _InputBar(
                      controller: _inputController,
                      isLoading: _isLoading,
                      isDarkMode: isDarkMode,
                      surfaceColor: surfaceColor,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      dividerColor: dividerColor,
                      onSend: _sendMessage,
                    ),
                  ],
                ),

                if (_showScrollToBottom)
                  Positioned(
                    bottom: 80,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: IconButton(
                        onPressed: () => _scrollToBottom(),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.all(5),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.darkHeader,
                        ),
                        icon: Icon(Icons.arrow_downward, size: 20),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Chat Bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isDarkMode;
  final Color surfaceColor;
  final Color textPrimary;

  const _MessageBubble({
    required this.message,
    required this.isDarkMode,
    required this.surfaceColor,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final bubbleColor = isUser
        ? (isDarkMode ? const Color(0xFF1565C0) : const Color(0xFF1976D2))
        : surfaceColor;
    final textColor = isUser ? Colors.white : textPrimary;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isUser
            ? Text(
                message.content,
                style: TextStyle(color: textColor, fontSize: 15),
              )
            : MarkdownBody(
                data: message.content,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(color: textColor, fontSize: 15, height: 1.6),
                  h3: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 2.0,
                  ),
                  strong: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                  listBullet: TextStyle(color: textColor, fontSize: 15),
                  horizontalRuleDecoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: isDarkMode
                            ? AppColors.darkDivider
                            : AppColors.divider,
                        width: 1.0,
                      ),
                    ),
                  ),
                  blockSpacing: 12.0,
                ),
              ),
      ),
    );
  }
}

// ─── Loading Bubble ──────────────────────────────────────────────────────────

class _LoadingBubble extends StatelessWidget {
  final bool isDarkMode;
  final Color surfaceColor;
  final Color textSecondary;

  const _LoadingBubble({
    required this.isDarkMode,
    required this.surfaceColor,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'กำลังวิเคราะห์...',
              style: TextStyle(color: textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Input Bar ───────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final bool isDarkMode;
  final Color surfaceColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color dividerColor;
  final void Function(String) onSend;

  const _InputBar({
    required this.controller,
    required this.isLoading,
    required this.isDarkMode,
    required this.surfaceColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.dividerColor,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final sendColor = isDarkMode
        ? const Color(0xFF42A5F5)
        : const Color(0xFF1976D2);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(top: BorderSide(color: dividerColor, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(color: textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'ถามเกี่ยวกับพอร์ต...',
                hintStyle: TextStyle(color: textSecondary),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 8,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: isLoading ? null : onSend,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: isLoading ? null : () => onSend(controller.text),
            icon: Icon(
              Icons.send_rounded,
              color: isLoading ? textSecondary : sendColor,
            ),
          ),
        ],
      ),
    );
  }
}
