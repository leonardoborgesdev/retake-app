# Status

Última atualização: 2026-08-03.

## O que já está pronto

App iOS nativo (SwiftUI), projeto gerado via [xcodegen](https://github.com/yonaskolb/XcodeGen)
a partir de `project.yml`. Duas funcionalidades:

1. **Compressão de vídeo** — importa da galeria (`PhotosPicker`), comprime com ffmpeg
   embutido (H.265/HEVC via [ffmpeg-kit-spm](https://github.com/tylerjonesio/ffmpeg-kit-spm),
   pinado em `5.1.2`), salva na galeria. Ver
   [`docs/superpowers/specs/2026-08-03-video-compressor-design.md`](docs/superpowers/specs/2026-08-03-video-compressor-design.md).
2. **Corte de silêncio/retake** — pipeline portado do repositório
   [Morfeu333/silence-retake-editing](https://github.com/Morfeu333/silence-retake-editing)
   (Python → Swift, fielmente, ver arquivos abaixo). Usa a API da AssemblyAI (nuvem) pra
   transcrição, ffmpeg local pra detecção acústica de silêncio e renderização dos cortes.
   Quando encontra uma repetição de frase (retake) na QA por re-transcrição, mostra uma
   tela pro usuário escolher qual trecho manter.

### Arquivos principais

| Arquivo | Responsabilidade |
|---|---|
| `VideoCompressor/ContentView.swift` | Tela principal — importar, cortar, comprimir |
| `VideoCompressor/VideoCompressionService.swift` | Wrapper do FFmpegKit pra compressão HEVC |
| `VideoCompressor/SilenceCutPlanner.swift` | Porta de `plan_silence_cuts.py` (puro, testado) |
| `VideoCompressor/CutRenderer.swift` | Porta de `render_cuts.py` — filtergraph trim/concat (puro, testado) |
| `VideoCompressor/CutRenderExecutor.swift` | Roda o filtergraph via FFmpegKit |
| `VideoCompressor/TranscriptQA.swift` | Porta de `qa_transcript.py` (puro, testado) |
| `VideoCompressor/CutMapper.swift` | Porta de `map_cuts_back.py` + `merge_cuts.py` (puro, testado) |
| `VideoCompressor/RetakeCandidate.swift` | Detecta candidatos a retake com timestamps, pra tela de revisão |
| `VideoCompressor/AssemblyAIClient.swift` | Cliente HTTP da API da AssemblyAI (upload + transcrição + polling) |
| `VideoCompressor/APIKeyStore.swift` | Guarda a chave da AssemblyAI no Keychain |
| `VideoCompressor/EditingPipeline.swift` | Orquestrador do pipeline de corte (state machine) |
| `VideoCompressor/SettingsView.swift` | Tela pra colar a chave de API |
| `VideoCompressor/RetakeReviewView.swift` | Tela de revisão manual de retakes |

## Validação já feita

- **Lógica pura testada de verdade**: 24 testes XCTest (`VideoCompressorTests/`) rodados
  num pacote SPM temporário no macOS (não depende de framework iOS) — todos passando.
  Confirma que a porta Python→Swift dos algoritmos de corte/QA está correta.
- **API do ffmpeg-kit confirmada contra os headers reais** do XCFramework baixado (não é
  suposição) — `FFmpegKit.executeAsync`, `ReturnCode`, `Statistics`, `Session`.
- **API da AssemblyAI confirmada** via documentação oficial (endpoints, nomes de campo,
  unidade de tempo — `words[].start/end` em milissegundos, `audio_duration` em segundos).

## Bloqueio atual

**O build completo pro iOS (simulador ou dispositivo) ainda não foi validado.** O Xcode
desse Mac (26.5) tinha o componente de plataforma "iOS 26.5" ausente — só a pasta do SDK
existia, faltava o registro completo. Rodando
`xcodebuild -downloadPlatform iOS` (precisa de ~8,5 GB livres — já liberamos espaço
limpando caches grandes de apps). Na última checagem esse download estava **lento**
(~45 MB/min, pode levar horas).

**Quando retomar esta sessão:**
1. Checar se o download terminou:
   `xcodebuild -showdestinations -project VideoCompressor.xcodeproj -scheme VideoCompressor`
   — se "Any iOS Device" não aparecer mais como "ineligible", terminou.
2. Rodar o build de verdade:
   `xcodebuild -project VideoCompressor.xcodeproj -scheme VideoCompressor -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build`
3. Corrigir qualquer erro de compilação que aparecer (o código nunca foi compilado de
   ponta a ponta pro SDK do iOS — só typecheck local + testes da lógica pura).
4. Plugar o iPhone 14 via USB, abrir o `.xcodeproj` no Xcode, escolher o Apple ID em
   Signing & Capabilities, apertar Run.

## Pendências / decisões em aberto

- Chave da API da AssemblyAI: usuário precisa colar a própria chave na tela de
  Configurações (ícone de engrenagem) antes de usar o corte de silêncio/retake.
- Conta Apple gratuita expira o app instalado em 7 dias (precisa reinstalar pelo Xcode).
- `RetakeReviewView` toca os dois trechos candidatos lado a lado — não testado
  visualmente ainda (sem simulador funcionando).
