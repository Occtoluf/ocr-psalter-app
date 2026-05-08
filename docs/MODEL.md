# Модельный пакет

## Состав

Мобильная версия модели называется `mobile_model_v1`.

Каталог приложения:

```text
OCRPsalterApp/Resources/ModelResources/mobile_model_v1/
  vocab.json
  preprocessing.json
  model_info.json
  CRNNLineRecognizer.mlpackage      # создаётся на Mac
```

Каталог исходной модели:

```text
Model/
  checkpoint_parts/
  restore_checkpoint.sh
  convert_to_coreml.py
  requirements-coreml.txt
```

## Почему checkpoint разбит на части

Исходный `.pt` весит около `116 МБ`. GitHub отклоняет обычные blob-файлы больше `100 МБ`, а в текущей среде `git-lfs` не установлен. Поэтому checkpoint хранится в трёх частях меньше лимита GitHub.

Восстановление:

```bash
./Model/restore_checkpoint.sh
```

После восстановления появится:

```text
Model/best_train_synth_plus_verified_latest_vocab_current_q20260504_072444.pt
```

## Конвертация в Core ML

```bash
python3 -m venv .venv-coreml
source .venv-coreml/bin/activate
pip install -r Model/requirements-coreml.txt
python Model/convert_to_coreml.py
```

Скрипт:

1. загружает checkpoint;
2. создаёт `CRNN` из архитектуры, встроенной в `convert_to_coreml.py`;
3. делает `torch.jit.trace`;
4. конвертирует модель через `coremltools`;
5. сохраняет `CRNNLineRecognizer.mlpackage` в ресурсы iOS-приложения.

Если CoreMLTools падает на `mlprogram`-конвертации CRNN/LSTM-графа, скрипт автоматически пробует `neuralnetwork` fallback и сохраняет:

```text
OCRPsalterApp/Resources/ModelResources/mobile_model_v1/CRNNLineRecognizer.mlmodel
```

Приложение ищет `.mlmodelc`, `.mlpackage` и `.mlmodel`, поэтому оба формата подходят.

## Параметры входа

```json
{
  "input_shape": [1, 1, 48, 1024],
  "color_space": "grayscale",
  "normalization": "uint8 / 255.0"
}
```

Строка масштабируется до высоты `48 px`; если ширина меньше `1024`, справа добавляется белый фон.

## Декодирование

Декодер находится в `CTCDecoder.swift`.

Алгоритм:

1. для каждого time-step выбрать класс с максимальным log probability;
2. удалить `blank` с индексом `0`;
3. схлопнуть последовательные повторы;
4. собрать Unicode-строку по `vocab.json`.
