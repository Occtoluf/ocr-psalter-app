# Model

В этом каталоге лежит исходная OCR-модель и инструменты подготовки Core ML пакета.

## Файлы

- `checkpoint_parts/` - checkpoint `.pt`, разбитый на части для GitHub;
- `restore_checkpoint.sh` - восстанавливает исходный `.pt`;
- `convert_to_coreml.py` - конвертирует `.pt` в `CRNNLineRecognizer.mlpackage`;
- `requirements-coreml.txt` - зависимости для конвертации;
- `vocab.json` - словарь модели.

## Команды

```bash
./Model/restore_checkpoint.sh
python3 -m venv .venv-coreml
source .venv-coreml/bin/activate
pip install -r Model/requirements-coreml.txt
python Model/convert_to_coreml.py
```

Результат конвертации:

```text
OCRPsalterApp/Resources/ModelResources/mobile_model_v1/CRNNLineRecognizer.mlpackage
```

Если `mlprogram`-конвертация не проходит, скрипт автоматически попробует формат `neuralnetwork` и сохранит:

```text
OCRPsalterApp/Resources/ModelResources/mobile_model_v1/CRNNLineRecognizer.mlmodel
```
