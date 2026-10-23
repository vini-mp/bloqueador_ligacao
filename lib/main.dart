
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BloqueadorApp());
}

// Canal privado de comunicação entre Flutter e Android.
const MethodChannel canalTelefonia = MethodChannel('bloqueador/telefonia');

class BloqueadorApp extends StatelessWidget {
  const BloqueadorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bloqueador de Ligações',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1769D2),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      ),
      home: const TelaPrincipal(),
    );
  }
}

class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  final TextEditingController _controlador = TextEditingController();

  List<String> _prefixos = [];
  List<Map<String, String>> _historico = [];
  bool _carregando = true;
  bool _autorizado = false;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      final prefixos =
          preferencias.getStringList('prefixos_bloqueio') ?? [];

      // Sincroniza os prefixos com o armazenamento nativo do Android.
      await canalTelefonia.invokeMethod<void>(
        'sincronizarPrefixos',
        {'prefixos': prefixos},
      );

      final autorizado =
          await canalTelefonia.invokeMethod<bool>(
                'verificarAutorizacao',
              ) ??
              false;

      final historicoBruto =
          await canalTelefonia.invokeMethod<List<dynamic>>(
                'obterHistorico',
              ) ??
              [];

      final historico = historicoBruto
          .whereType<Map>()
          .map((item) => Map<String, String>.from(item))
          .toList();

      if (!mounted) return;

      setState(() {
        _prefixos = prefixos;
        _historico = historico;
        _autorizado = autorizado;
        _carregando = false;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;

      setState(() => _carregando = false);
      _mostrarMensagem('Erro na integração Android: ${e.message}');
    } catch (_) {
      if (!mounted) return;

      setState(() => _carregando = false);
      _mostrarMensagem('Não foi possível carregar os dados.');
    }
  }

  String? _normalizarPrefixo(String entrada) {
    final prefixo = entrada.replaceAll(RegExp(r'[\s()-]'), '');

    if (!RegExp(r'^\+?\d+$').hasMatch(prefixo)) return null;
    if (prefixo.length < 2 || prefixo.length > 16) return null;

    return prefixo;
  }

  Future<void> _adicionarPrefixo() async {
    final prefixo = _normalizarPrefixo(_controlador.text.trim());

    if (prefixo == null) {
      _mostrarMensagem('Digite um prefixo numérico válido.');
      return;
    }

    if (_prefixos.contains(prefixo)) {
      _mostrarMensagem('Esse prefixo já está cadastrado.');
      return;
    }

    final novosPrefixos = [..._prefixos, prefixo]..sort();
    final preferencias = await SharedPreferences.getInstance();

    // Persiste o cadastro localmente.
    await preferencias.setStringList(
      'prefixos_bloqueio',
      novosPrefixos,
    );

    try {
      await canalTelefonia.invokeMethod<void>(
        'sincronizarPrefixos',
        {'prefixos': novosPrefixos},
      );

      if (!mounted) return;

      setState(() {
        _prefixos = novosPrefixos;
        _controlador.clear();
      });

      _mostrarMensagem('Prefixo cadastrado.');
    } catch (_) {
      _mostrarMensagem(
        'Prefixo salvo, mas a sincronização com o Android falhou. '
        'Reabra o aplicativo para tentar novamente.',
      );
    }
  }

  Future<void> _excluirPrefixo(String prefixo) async {
    final novosPrefixos =
        _prefixos.where((p) => p != prefixo).toList();

    final preferencias = await SharedPreferences.getInstance();

    await preferencias.setStringList(
      'prefixos_bloqueio',
      novosPrefixos,
    );

    try {
      await canalTelefonia.invokeMethod<void>(
        'sincronizarPrefixos',
        {'prefixos': novosPrefixos},
      );

      if (!mounted) return;

      setState(() => _prefixos = novosPrefixos);
      _mostrarMensagem('Prefixo removido.');
    } catch (_) {
      _mostrarMensagem(
        'Não foi possível sincronizar a exclusão com o Android.',
      );
    }
  }

  Future<void> _solicitarAutorizacao() async {
    try {
      await canalTelefonia.invokeMethod<void>(
        'solicitarAutorizacao',
      );

      await Future<void>.delayed(
        const Duration(milliseconds: 500),
      );

      final autorizado =
          await canalTelefonia.invokeMethod<bool>(
                'verificarAutorizacao',
              ) ??
              false;

      if (!mounted) return;

      setState(() => _autorizado = autorizado);

      _mostrarMensagem(
        autorizado
            ? 'Filtragem de chamadas autorizada.'
            : 'A autorização ainda não foi concedida.',
      );
    } on PlatformException catch (e) {
      _mostrarMensagem(
        'Não foi possível solicitar autorização: ${e.message}',
      );
    }
  }

  Future<void> _atualizarHistorico() async {
    try {
      final registros =
          await canalTelefonia.invokeMethod<List<dynamic>>(
                'obterHistorico',
              ) ??
              [];

      if (!mounted) return;

      setState(() {
        _historico = registros
            .whereType<Map>()
            .map((item) => Map<String, String>.from(item))
            .toList();
      });
    } catch (_) {
      _mostrarMensagem('Não foi possível carregar o histórico.');
    }
  }

  void _mostrarMensagem(String mensagem) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(mensagem)),
      );
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bloqueador de Ligações',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1769D2),
        foregroundColor: Colors.white,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: Colors.white,
                    child: ListTile(
                      leading: Icon(
                        _autorizado
                            ? Icons.shield
                            : Icons.shield_outlined,
                        color: _autorizado
                            ? Colors.green
                            : Colors.orange,
                        size: 30,
                      ),
                      title: Text(
                        _autorizado
                            ? 'Filtragem autorizada'
                            : 'Autorize a filtragem',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        _autorizado
                            ? 'O Android pode encaminhar chamadas ao serviço.'
                            : 'Necessário para habilitar o bloqueio de chamadas.',
                      ),
                      trailing: _autorizado
                          ? const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: _autorizado
                          ? null
                          : _solicitarAutorizacao,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Adicionar prefixo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controlador,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: 'Ex.: 031 ou +5531',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onSubmitted: (_) => _adicionarPrefixo(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 56,
                        child: FilledButton(
                          onPressed: _adicionarPrefixo,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1769D2),
                          ),
                          child: const Icon(Icons.add),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Card(
                    color: Colors.white,
                    child: ListTile(
                      leading: const Icon(
                        Icons.history,
                        color: Color(0xFF1769D2),
                        size: 30,
                      ),
                      title: const Text(
                        'Histórico de bloqueios',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('${_historico.length} registros'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await _atualizarHistorico();

                        if (!mounted) return;

                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => TelaHistorico(
                              registros: _historico,
                            ),
                          ),
                        );

                        await _atualizarHistorico();
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Prefixos cadastrados',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_prefixos.isEmpty)
                    const Card(
                      color: Colors.white,
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(
                              Icons.phone_disabled,
                              size: 40,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text('Nenhum prefixo cadastrado'),
                            Text('Adicione um prefixo para começar.'),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._prefixos.map(
                      (prefixo) => Card(
                        color: Colors.white,
                        child: ListTile(
                          leading: const Icon(
                            Icons.phone_disabled,
                            color: Color(0xFF1769D2),
                          ),
                          title: Text(
                            prefixo,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: const Text('Prefixo cadastrado'),
                          trailing: IconButton(
                            tooltip: 'Excluir prefixo',
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () =>
                                _excluirPrefixo(prefixo),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'Os números são analisados localmente pelo Android. '
                    'O funcionamento depende da autorização do sistema.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}

class TelaHistorico extends StatelessWidget {
  const TelaHistorico({
    super.key,
    required this.registros,
  });

  final List<Map<String, String>> registros;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de bloqueios'),
        backgroundColor: const Color(0xFF1769D2),
        foregroundColor: Colors.white,
      ),
      body: registros.isEmpty
          ? const Center(
              child: Text('Nenhum bloqueio registrado.'),
            )
          : ListView.builder(
              itemCount: registros.length,
              itemBuilder: (context, index) {
                // Exibe primeiro o registro mais recente.
                final registro =
                    registros[registros.length - 1 - index];

                return ListTile(
                  leading: const Icon(
                    Icons.phone_missed,
                    color: Colors.red,
                  ),
                  title: Text(
                    registro['numero'] ?? 'Número indisponível',
                  ),
                  subtitle: Text(
                    'Prefixo: ${registro['prefixo'] ?? ''}\n'
                    '${registro['data'] ?? ''}',
                  ),
                  isThreeLine: true,
                );
              },
            ),
    );
  }
}
