# VideoCompressor — Design

## Contexto

App nativo iOS para uso pessoal (sideload via Xcode / TestFlight, sem publicação na App
Store) que comprime vídeos importados da Galeria de Fotos mantendo qualidade visual, e
salva o resultado de volta na galeria como um novo item. Alvo: iPhone 14, iOS 16+.

## Objetivo

Reduzir o tamanho de arquivo de vídeos gravados no iPhone sem perda perceptível de
qualidade, usando ffmpeg embutido no próprio app (não existe ffmpeg nativo no iOS — a
Apple não distribui essa ferramenta no sistema operacional; todo app "com ffmpeg no
iPhone" embute uma cópia compilada da biblioteca dentro do seu próprio binário). O
processamento roda 100% localmente no processador do iPhone, sem servidor ou internet.

## Escopo

- Um único vídeo por vez (sem fila/lote).
- Preset de compressão fixo, sem controles ajustáveis pelo usuário.
- Vídeo comprimido salvo na galeria; vídeo original nunca é modificado ou apagado.
- Sem suíte de testes automatizada (validação manual, uso pessoal).

Fora de escopo: processamento em lote, ajuste manual de qualidade, upload/nuvem,
publicação na App Store, suporte a iPads/Macs.

## Arquitetura

App SwiftUI de tela única:

```
[Importar vídeo] → PhotosPicker → cópia para arquivo temporário
        ↓
[Comprimir] → FFmpegKit.executeAsync (H.265/HEVC) → ProgressView
        ↓
Resultado: tamanho antes/depois → PHPhotoLibrary salva output.mp4 na galeria
        ↓
Limpeza dos arquivos temporários
```

## Componentes

- **`PhotosPicker`** (`PhotosUI`, nativo): seleção do vídeo, sem exigir permissão de
  biblioteca completa — apenas do item escolhido.
- **`FFmpegKit`** (via Swift Package Manager, XCFramework binário de um fork mantido do
  ffmpeg-kit): executa o comando de compressão dentro do processo do app.
- **`PHPhotoLibrary`**: grava o vídeo comprimido como novo item na galeria.
- **Arquivos temporários**: `FileManager.default.temporaryDirectory` para o input
  copiado do picker e o output comprimido; removidos após salvar (ou após erro).

## Fluxo de dados

1. Usuário escolhe o vídeo no `PhotosPicker`. O app copia o conteúdo para um arquivo
   temporário local (o ffmpeg precisa de um path de arquivo, não de um asset de galeria).
2. O app executa o comando ffmpeg com preset fixo:
   ```
   -i input.mov -c:v libx265 -crf 23 -preset medium -c:a copy -tag:v hvc1 output.mp4
   ```
   - `libx265`/HEVC: mantém qualidade visual com bitrate bem menor que o H.264 original.
   - `-crf 23`: fator de qualidade constante calibrado para "visualmente sem perdas".
   - `-c:a copy`: preserva o áudio original sem recompressão.
   - `-tag:v hvc1`: garante que o app Fotos/QuickTime reconheça o HEVC corretamente.
3. O progresso é lido via callback de estatísticas do FFmpegKit (tempo processado /
   duração total do vídeo) e exibido numa `ProgressView`.
4. Ao concluir, o app salva `output.mp4` na galeria via
   `PHPhotoLibrary.shared().performChanges`, exibe tamanho antes/depois e economia em %,
   e remove os arquivos temporários. O vídeo original na galeria não é tocado.

## Tratamento de erros

- Falha ao copiar do picker, falha do ffmpeg (código de retorno de erro) ou falha ao
  salvar na galeria: alerta simples com a mensagem de erro; o app permanece utilizável.
- Se o usuário sair da tela durante a compressão, o processo ffmpeg em andamento é
  cancelado via `FFmpegKit.cancel()` e os arquivos temporários são limpos.

## Integração do ffmpeg

Distribuição via **Swift Package Manager**: XCFramework binário de um fork comunitário
mantido do ffmpeg-kit, adicionado como Swift Package direto no Xcode — sem CocoaPods,
sem compilação local do ffmpeg.

## Teste

Validação manual (sem suíte automatizada, por ser projeto de uso pessoal):
1. Importar um vídeo real gravado no iPhone 14.
2. Confirmar que o resultado abre normalmente no app Fotos.
3. Comparar tamanho de arquivo e qualidade visual lado a lado com o original.
4. Testar cancelamento durante a compressão (sair da tela no meio do processo).
