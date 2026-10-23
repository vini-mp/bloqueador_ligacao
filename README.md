
# 📵 Bloqueador de Ligações

Aplicativo Android desenvolvido com **Flutter, Dart e Kotlin** para bloquear chamadas recebidas com base em prefixos telefônicos definidos pelo usuário.

O objetivo é oferecer uma maneira simples de filtrar chamadas indesejadas, com armazenamento local dos prefixos e registro das chamadas bloqueadas.

##  Funcionalidades

- **Bloqueio por prefixo:** rejeita chamadas recebidas que correspondam aos prefixos cadastrados.
- **Gerenciamento de prefixos:** permite adicionar e excluir prefixos.
- **Persistência local:** mantém os prefixos salvos após fechar e abrir o aplicativo.
- **Histórico de bloqueios:** registra o número, o prefixo correspondente e a data e hora.
- **Histórico organizado:** exibe os bloqueios mais recentes primeiro.
- **Integração nativa com Android:** utiliza o `CallScreeningService` para filtrar chamadas.
- **Processamento local:** o bloqueio não depende de um servidor remoto.

## Tecnologias utilizadas

- **Flutter:** construção da interface.
- **Dart:** lógica da aplicação.
- **Kotlin:** integração com os recursos nativos do Android.
- **SharedPreferences:** armazenamento local dos prefixos.
- **Android CallScreeningService:** mecanismo de filtragem de chamadas.

## Requisitos

Para executar o projeto, você precisará de:

- Flutter SDK.
- Android SDK e ferramentas de compilação.
- Visual Studio Code ou outra IDE compatível.
- Dispositivo Android ou emulador para testes.

## Como executar

### 1. Clone o repositório

```bash
git clone https://github.com/vini-mp/bloqueador_ligacao.git
```

### 2. Entre na pasta do projeto

```bash
cd bloqueador_ligacao
```

### 3. Instale as dependências

```bash
flutter pub get
```

### 4. Execute o aplicativo

Conecte um dispositivo Android ou inicie um emulador e execute:

```bash
flutter run
```

## Como gerar o APK

Para gerar a versão de lançamento, execute:

```bash
flutter build apk --release
```

O arquivo será gerado em:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Privacidade

O aplicativo foi desenvolvido para realizar a filtragem localmente.

- Os prefixos e o histórico são armazenados no dispositivo.
- O bloqueio não depende de um servidor remoto.
- A filtragem requer autorização do Android.
- O aplicativo não precisa consultar um servidor externo para comparar os prefixos cadastrados.

## Observações

O funcionamento depende da autorização concedida pelo usuário e do suporte do dispositivo Android. Recomenda-se testar a filtragem após a instalação.


## 📥 Download

**Baixe a versão mais recente do Bloqueador de Ligações para Android.**

👉 [Acessar Releases e baixar o APK](https://github.com/vini-mp/bloqueador_ligacao/releases/tag/v1.0.0)

Na página de Releases, baixe o arquivo `app-release.apk` e instale-o no seu dispositivo Android.

> **Observação:** pode ser necessário autorizar a instalação de aplicativos provenientes dessa fonte nas configurações do Android.

