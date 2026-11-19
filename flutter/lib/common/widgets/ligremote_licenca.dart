// LIG Remote (LIG-it Tecnologia), modificação sobre o RustDesk (AGPL-3.0).
// Cartão da tela inicial: licença (plano, validade, dias restantes) e o link de instalação
// para mandar a quem vai receber o acesso (ADR 0050 F4).
// Os dados vêm do campo "ligremote" de /api/login e /api/currentUser do servidor LIG Remote.
// Servidor sem esse campo = cartão some (comportamento do RustDesk original).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../common.dart';
import '../../models/platform_model.dart';
import 'login.dart';

const _kChaveLocal = 'ligremote_info';

class LigRemoteInfo {
  final RxMap<String, dynamic> dados = <String, dynamic>{}.obs;
  bool _carregado = false;

  /// Mostra o último dado salvo enquanto o currentUser não volta (abrir sem rede, por exemplo).
  void carregaLocal() {
    if (_carregado) return;
    _carregado = true;
    try {
      final s = bind.mainGetLocalOption(key: _kChaveLocal);
      if (s.isNotEmpty) {
        final v = jsonDecode(s);
        if (v is Map) dados.assignAll(Map<String, dynamic>.from(v));
      }
    } catch (_) {}
  }

  /// Corpo de /api/login ou /api/currentUser.
  void atualiza(dynamic corpo) {
    final v = corpo is Map ? corpo['ligremote'] : null;
    if (v is Map && v.isNotEmpty) {
      dados.assignAll(Map<String, dynamic>.from(v));
      bind.mainSetLocalOption(key: _kChaveLocal, value: jsonEncode(v));
    } else {
      limpa();
    }
  }

  void limpa() {
    dados.clear();
    bind.mainSetLocalOption(key: _kChaveLocal, value: '');
  }
}

final ligremoteInfo = LigRemoteInfo();

String _dataBr(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class LigRemoteLicencaCard extends StatelessWidget {
  const LigRemoteLicencaCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ligremoteInfo.carregaLocal();
    return Obx(() {
      final d = ligremoteInfo.dados;
      final theme = Theme.of(context);
      final fraco = theme.textTheme.bodySmall?.color?.withOpacity(0.7);
      if (gFFI.userModel.userName.value.isEmpty) {
        // ADR 0050 F3: sem login a conexão de saída é recusada no servidor, então o "Entrar"
        // fica à vista. Quem só recebe acesso não precisa entrar, e o texto deixa isso claro.
        return Container(
          margin: const EdgeInsets.only(left: 20, right: 11, top: 14),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: MyTheme.accent.withOpacity(0.35)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Vai acessar outros computadores?',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                  'Entre com o e-mail e a senha que você recebeu da LIG Remote. '
                  'Para só receber acesso, não precisa entrar.',
                  style: TextStyle(fontSize: 12, color: fraco)),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => loginDialog(),
                icon: const Icon(Icons.login, size: 16),
                label: const Text('Entrar', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: const Size(0, 32),
                ),
              ),
            ],
          ),
        );
      }
      if (d.isEmpty) {
        return const SizedBox.shrink();
      }
      final cliente = (d['cliente'] ?? '').toString();
      final plano = (d['plano'] ?? '').toString();
      final ciclo = (d['ciclo'] ?? '').toString();
      final link = (d['link_instalacao'] ?? '').toString();

      // validade: recalcula pela data (o dado salvo pode ser de dias atrás)
      String validade = 'Sem vencimento';
      Color? corValidade;
      final va = DateTime.tryParse((d['valida_ate'] ?? '').toString());
      if (va != null) {
        final hoje = DateTime.now();
        final dias = DateTime(va.year, va.month, va.day)
            .difference(DateTime(hoje.year, hoje.month, hoje.day))
            .inDays;
        if (dias < 0) {
          validade = 'Vencida em ${_dataBr(va)}';
          corValidade = Colors.red;
        } else {
          final falta = dias == 0
              ? 'vence hoje'
              : dias == 1
                  ? 'falta 1 dia'
                  : 'faltam $dias dias';
          validade = 'Até ${_dataBr(va)} ($falta)';
          if (dias <= 30) corValidade = Colors.orange;
        }
      }

      final titulo = [cliente, plano].where((s) => s.isNotEmpty).join(' - ');
      return Container(
        margin: const EdgeInsets.only(left: 20, right: 11, top: 14),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: MyTheme.accent.withOpacity(0.35)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Licença', style: TextStyle(fontSize: 11, color: fraco)),
            if (titulo.isNotEmpty)
              Text(titulo,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text(ciclo.isNotEmpty ? '$ciclo - $validade' : validade,
                style: TextStyle(fontSize: 12, color: corValidade ?? fraco)),
            const Divider(height: 18),
            const Text('Vai acessar outro computador?',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            if (link.isEmpty)
              Text('Peça o link de instalação ao gestor da sua conta.',
                  style: TextStyle(fontSize: 12, color: fraco))
            else ...[
              Text('Envie este link para instalar o LIG Remote nele:',
                  style: TextStyle(fontSize: 12, color: fraco)),
              const SizedBox(height: 4),
              SelectableText(link,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 11, color: MyTheme.accent)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _botao(Icons.copy, 'Copiar link', () {
                    Clipboard.setData(ClipboardData(text: link));
                    showToast('Link copiado');
                  }),
                  _botao(Icons.chat, 'WhatsApp', () {
                    final msg =
                        'Para eu acessar seu computador, instale o LIG Remote por este link: $link';
                    launchUrl(
                        Uri.parse(
                            'https://wa.me/?text=${Uri.encodeComponent(msg)}'),
                        mode: LaunchMode.externalApplication);
                  }),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _botao(IconData icone, String texto, VoidCallback acao) => OutlinedButton.icon(
        onPressed: acao,
        icon: Icon(icone, size: 14),
        label: Text(texto, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: const Size(0, 28),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
}
