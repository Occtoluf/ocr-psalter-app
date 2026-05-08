# OCR Psalter App

iOS-приложение для демонстрации OCR-пайплайна печатного церковнославянского текста. Минимальная версия: iOS 17.

Приложение рассчитано на защиту диссертации: пользователь сканирует страницу, приложение выделяет строки, запускает строковую CRNN-модель через Core ML, декодирует CTC-выход в Unicode и показывает редактируемый результат.

## Что умеет приложение

- сканирование страницы через системный `VisionKit` document scanner;
- локальная сегментация страницы на строки;
- ручное включение/отключение найденных строк перед OCR;
- резервный режим распознавания одной строки из фото;
- запуск CRNN через `Core ML`;
- CTC greedy decode по `vocab.json`;
- редактирование результата построчно;
- копирование текста;
- локальная история распознаваний.

Сервер, интернет, аккаунты и внешнее хранилище не используются.

## Структура

```text
OCRPsalterApp.xcodeproj
OCRPsalterApp/
  Application/                 точка входа SwiftUI
  Models/                      Codable-модели результата, vocab, metadata
  Services/                    Core ML OCR, CTC decoder, сегментация, история
  Views/                       экраны приложения
  Resources/
    ModelResources/
      mobile_model_v1/         vocab + metadata + Core ML модель после конвертации
Model/
  checkpoint_parts/            PyTorch checkpoint, разбитый на GitHub-safe части
  restore_checkpoint.sh        восстановление .pt из частей
  convert_to_coreml.py         .pt -> Core ML .mlpackage
  requirements-coreml.txt      зависимости конвертации
docs/
  ARCHITECTURE.md              архитектура приложения
  MODEL.md                     модельный пакет и конвертация
```

## Быстрый запуск на Mac

1. Откройте проект:

```bash
open OCRPsalterApp.xcodeproj
```

2. Выберите signing team в настройках target `OCRPsalterApp`.

3. Если `CRNNLineRecognizer.mlpackage` ещё не создан, соберите его:

```bash
./Model/restore_checkpoint.sh
python3 -m venv .venv-coreml
source .venv-coreml/bin/activate
pip install -r Model/requirements-coreml.txt
python Model/convert_to_coreml.py
```

4. Откройте проект в Xcode ещё раз, убедитесь, что файл появился здесь:

```text
OCRPsalterApp/Resources/ModelResources/mobile_model_v1/CRNNLineRecognizer.mlpackage
```

5. Запустите приложение на iPhone. Сканер документов `VisionKit` лучше проверять на реальном устройстве.

## Модель

В репозиторий включён checkpoint:

```text
best_train_synth_plus_verified_latest_vocab_current_q20260504_072444.pt
```

Из-за ограничения GitHub на одиночные файлы больше 100 МБ checkpoint хранится частями:

```text
Model/checkpoint_parts/checkpoint.pt.part-00
Model/checkpoint_parts/checkpoint.pt.part-01
Model/checkpoint_parts/checkpoint.pt.part-02
```

Скрипт `Model/restore_checkpoint.sh` восстанавливает исходный `.pt` и проверяет SHA256.

Метрики модели по `RESULTS.md` основного OCR-проекта:

| Метрика | Значение |
| --- | ---: |
| CER | 0.029 |
| WER | 0.139 |
| diaCR | 0.885 |

Архитектура: CRNN, CNN + 2×BiLSTM + CTC.

## Важное ограничение

CRNN распознаёт не страницу целиком, а одну строку. Поэтому page-level OCR в приложении состоит из этапов:

```text
фото страницы -> выравнивание VisionKit -> сегментация строк -> CRNN по каждой строке -> CTC decode -> сборка текста
```

Качество полного сценария зависит не только от CER модели, но и от качества сегментации строк. Для защиты в приложении есть резервный режим `Распознать строку`, который показывает работу CRNN отдельно от сегментации страницы.

## Вход Core ML модели

Приложение ожидает:

```text
name: line_image
shape: [1, 1, 48, 1024]
type: Float32
range: 0.0...1.0
```

Изображение строки масштабируется до высоты `48 px`, сохраняет пропорции и дополняется белым фоном до ширины `1024 px`.

Выход:

```text
name: log_probs
shape: [time, 1, vocab_size]
decoder: CTC greedy, blank index = 0
```

## Демонстрационный сценарий

1. Открыть приложение.
2. Нажать `Сканировать страницу`.
3. Сфотографировать страницу печатного церковнославянского текста.
4. Проверить найденные строки.
5. Нажать `Распознать выбранные строки`.
6. Показать результат, при необходимости исправить текст.
7. Сохранить в историю.

Резервный сценарий:

1. Открыть `Распознать строку`.
2. Выбрать фото одной строки.
3. Запустить CRNN и показать результат.
