# Mitsubishi Mobile App

Este é o aplicativo mobile da **Mitsubishi**, desenvolvido em Flutter. A aplicação é voltada para **agendamento de corridas** utilizadas por profissionais autorizados da Mitsubishi.

## 📱 Plataforma

- **Flutter** 3.x
- Compatível com **Android** e **iOS**

---

## 🧩 Funcionalidades

- Agendamento de corridas
- Interface moderna e responsiva
- Integração com API interna (via VPN)

---

## 🚀 Primeiros Passos

### Pré-requisitos

- Flutter SDK `>=3.0.0 <4.0.0`
- Android Studio ou VSCode
- Dispositivo físico (emulador **não recomendado**)
- Acesso à VPN corporativa da Mitsubishi (obrigatório para usar a API)

### Instalação

```bash
git clone http://git.kaspper.com.br/projetos/mitsubishi/mitsubishi-mobile.git
cd mitsubishi
flutter pub get
flutter run
```

---

## 🔐 Acesso à API

> **Importante:** a API utilizada pelo app está disponível **apenas via VPN corporativa**.  
> Certifique-se de estar conectado à VPN da Mitsubishi **antes de executar ou debugar o app**.

---

## 🧷 Dependências Críticas

Algumas dependências requerem atenção especial.  
⚠️ **A versão da biblioteca `intl` deve ser mantida fixa na versão `0.19.0`**.

### Trecho do `pubspec.yaml`:

```yaml
dependencies:
  intl: 0.19.0
```

> Atualizações automáticas dessa dependência podem causar problemas com internacionalização de datas e moedas.

---

## 🛠️ Outras Dependências

O projeto utiliza diversas bibliotecas para performance, cache, roteamento, persistência e muito mais, incluindo:

- `go_router`
- `cached_network_image`
- `shared_preferences`
- `sqflite`
- `flutter_localizations`
- `google_fonts`

Veja o `pubspec.yaml` completo para detalhes.

---

## 🔖 Versão

Versão atual: `1.0.0+1`

---

## 📁 Estrutura de Assets

Todos os assets do app estão organizados nas seguintes pastas:

- `assets/fonts/`
- `assets/images/`
- `assets/videos/`
- `assets/audios/`
- `assets/rive_animations/`
- `assets/pdfs/`
- `assets/jsons/`

---

## 👥 Equipe

Este projeto é mantido pela equipe da Kaspper em parceria com a Mitsubishi Motors.

---

## 🧼 Linting e Padrões

Este projeto segue as boas práticas definidas pelos pacotes:

- `flutter_lints`
- `lints`

---

## 📄 Licença

Este projeto é privado e de uso exclusivo da Mitsubishi Motors e seus parceiros autorizados.
