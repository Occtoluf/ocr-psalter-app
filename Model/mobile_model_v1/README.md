# mobile_model_v1

Пакет мобильной версии строковой OCR-модели.

Состав:

- `CRNNLineRecognizer.mlpackage` - Core ML модель, создаётся скриптом `../convert_to_coreml.py`;
- `vocab.json` - словарь, совместимый с checkpoint;
- `preprocessing.json` - параметры подготовки строки перед inference;
- `model_info.json` - версия, метрики и параметры декодирования.

Источник:

- checkpoint: `../best_train_synth_plus_verified_latest_vocab_current_q20260504_072444.pt`;
- архитектура: CRNN CNN + 2×BiLSTM + CTC, код конвертации встроен в `../convert_to_coreml.py`;
- качество по `RESULTS.md`: CER `0.029`, WER `0.139`, diaCR `0.885`.

Команда конвертации:

```bash
python Mobile-app/Model/convert_to_coreml.py
```

По умолчанию скрипт сохраняет результат в каталог приложения:
`Mobile-app/OCRPsalterApp/Resources/ModelResources/mobile_model_v1/`.

Если нужно только обновить JSON-метаданные без Core ML:

```bash
python Mobile-app/Model/convert_to_coreml.py --skip-coreml
```
