# Архитектура приложения

## Назначение

`OCR Psalter App` - демонстрационное iOS-приложение для локального распознавания печатного церковнославянского текста.

Основная исследовательская модель уже обучена отдельно в Python-проекте. Мобильное приложение показывает, как эта строковая CRNN-модель используется в полном пользовательском сценарии.

## Поток данных

```text
VisionKit scan
  -> UIImage страницы
  -> PageLineSegmenter
  -> [LineCandidate]
  -> LineImagePreprocessor
  -> Core ML CRNN
  -> CTCDecoder
  -> [RecognizedLine]
  -> ResultView / HistoryStore
```

## Модули

### Scan / UI

- `HomeView` - основной экран: скан страницы, одна строка, история.
- `ScanPageView` - запуск `VNDocumentCameraViewController` и первичная сегментация.
- `LineReviewView` - список найденных строк с переключателями.
- `SingleLineView` - резервный режим для проверки CRNN без page segmentation.
- `ResultView` - редактирование, копирование, сохранение.
- `HistoryView` - локальная история.

### OCR

- `OCRService` - загружает Core ML модель и vocab, запускает inference.
- `LineImagePreprocessor` - приводит строку к `[1, 1, 48, 1024]`.
- `CTCDecoder` - greedy decode: blank removal + collapse repeats.
- `Vocab` - читает `vocab.json` из модельного пакета.

### Page-level preprocessing

- `PageLineSegmenter` - MVP-сегментация строк по горизонтальным проекциям тёмных пикселей.
- `ImageUtilities` - normalizing orientation, crop, grayscale raster.

### Storage

- `HistoryStore` - JSON-файл в Documents приложения.
- `RecognizedPage` / `RecognizedLine` - Codable-модели результата.

## Почему есть режим одной строки

Модель CRNN обучена на строках и показывает CER `0.029`, но она не решает задачу поиска строк на странице. Ошибка сегментации может испортить результат даже при хорошей OCR-модели.

Поэтому режим одной строки нужен как демонстрационная страховка: он отделяет качество CRNN от качества page-level сегментации.

## Замена модели

Модель изолирована в каталоге:

```text
OCRPsalterApp/Resources/ModelResources/mobile_model_v1/
```

Для замены версии нужно обновить:

- `CRNNLineRecognizer.mlpackage` или `.mlmodelc`;
- `vocab.json`, если изменился словарь;
- `model_info.json`;
- `preprocessing.json`, если изменился вход модели.

UI и история от конкретной версии модели не зависят.
