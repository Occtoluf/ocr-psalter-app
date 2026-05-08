#!/usr/bin/env python3
"""Convert the current CRNN PyTorch checkpoint to a Core ML model package.

Run from the repository root:

    python Mobile-app/Model/convert_to_coreml.py

The script intentionally lives next to the mobile model files so the iOS model
bundle can be rebuilt without touching the training pipeline.
"""

from __future__ import annotations

import argparse
import json
import shutil
from datetime import date
from pathlib import Path


MODEL_DIR = Path(__file__).resolve().parent
DEFAULT_CHECKPOINT = (
    MODEL_DIR / "best_train_synth_plus_verified_latest_vocab_current_q20260504_072444.pt"
)
DEFAULT_VOCAB = MODEL_DIR / "vocab.json"
DEFAULT_PACKAGE_DIR = (
    MODEL_DIR.parent / "OCRPsalterApp" / "Resources" / "ModelResources" / "mobile_model_v1"
)


def load_vocab_size(vocab_path: Path) -> int:
    with vocab_path.open(encoding="utf-8") as f:
        vocab = json.load(f)
    if "_total" in vocab:
        return int(vocab["_total"])
    if "classes" in vocab:
        return len(vocab["classes"])
    raise ValueError(f"Cannot infer vocab size from {vocab_path}")


def load_checkpoint_state(torch_module, checkpoint_path: Path) -> dict:
    state = torch_module.load(checkpoint_path, map_location="cpu", weights_only=False)
    if isinstance(state, dict):
        if "model" in state:
            return state["model"]
        if "state_dict" in state:
            return state["state_dict"]
        if all(hasattr(v, "shape") for v in state.values()):
            return state
    raise ValueError(
        "Unsupported checkpoint format. Expected a dict with 'model', "
        "'state_dict', or a raw state_dict."
    )


def strip_module_prefix(state_dict: dict) -> dict:
    if not any(k.startswith("module.") for k in state_dict):
        return state_dict
    return {k.removeprefix("module."): v for k, v in state_dict.items()}


def write_json(path: Path, data: dict) -> None:
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def write_package_metadata(
    package_dir: Path,
    checkpoint_path: Path,
    vocab_path: Path,
    input_width: int,
    input_height: int,
    vocab_size: int,
    mlpackage_name: str,
) -> None:
    package_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(vocab_path, package_dir / "vocab.json")

    preprocessing = {
        "input_name": "line_image",
        "input_shape": [1, 1, input_height, input_width],
        "color_space": "grayscale",
        "resize": {
            "height": input_height,
            "keep_aspect_ratio": True,
            "pad_to_width": input_width,
            "pad_value": 1.0,
            "overflow": "scale_down_or_center_crop_after_review",
        },
        "pixel_range": [0.0, 1.0],
        "normalization": "uint8 / 255.0",
        "text_color": "dark_pixels_near_0",
        "background_color": "white_pixels_near_1",
        "line_padding": {
            "prefer_extra_top_padding": True,
            "reason": "titla, breathing marks, accents, and superscript letters"
        }
    }
    write_json(package_dir / "preprocessing.json", preprocessing)

    model_info = {
        "name": "mobile_model_v1",
        "coreml_model": mlpackage_name,
        "source_checkpoint": checkpoint_path.name,
        "architecture": "CRNN_CNN_BiLSTM_CTC",
        "vocab": "vocab.json",
        "vocab_size": vocab_size,
        "input_height": input_height,
        "input_width": input_width,
        "input_channels": 1,
        "output": {
            "name": "log_probs",
            "shape": ["time", 1, vocab_size],
            "activation": "log_softmax"
        },
        "decoder": {
            "type": "ctc_greedy",
            "blank_index": 0,
            "collapse_repeats": True,
            "remove_blank": True
        },
        "metrics": {
            "cer": 0.029,
            "wer": 0.139,
            "diacritic_accuracy": 0.885,
            "source": "RESULTS.md, train queue 20260504_072444"
        },
        "export_date": date.today().isoformat()
    }
    write_json(package_dir / "model_info.json", model_info)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkpoint", type=Path, default=DEFAULT_CHECKPOINT)
    parser.add_argument("--vocab", type=Path, default=DEFAULT_VOCAB)
    parser.add_argument("--package-dir", type=Path, default=DEFAULT_PACKAGE_DIR)
    parser.add_argument("--height", type=int, default=48)
    parser.add_argument("--width", type=int, default=1024)
    parser.add_argument("--lstm-hidden", type=int, default=256)
    parser.add_argument("--deployment-target", default="iOS16")
    parser.add_argument("--output-name", default="CRNNLineRecognizer.mlpackage")
    parser.add_argument("--skip-coreml", action="store_true",
                        help="Only refresh package metadata, do not convert the model.")
    args = parser.parse_args()

    checkpoint_path = args.checkpoint.resolve()
    vocab_path = args.vocab.resolve()
    package_dir = args.package_dir.resolve()
    output_path = package_dir / args.output_name

    if not checkpoint_path.exists():
        raise FileNotFoundError(checkpoint_path)
    if not vocab_path.exists():
        raise FileNotFoundError(vocab_path)

    vocab_size = load_vocab_size(vocab_path)
    write_package_metadata(
        package_dir=package_dir,
        checkpoint_path=checkpoint_path,
        vocab_path=vocab_path,
        input_width=args.width,
        input_height=args.height,
        vocab_size=vocab_size,
        mlpackage_name=args.output_name,
    )

    if args.skip_coreml:
        print(f"Metadata package refreshed: {package_dir}")
        return

    try:
        import numpy as np
        import torch
        import torch.nn as nn
        import coremltools as ct
    except ImportError as exc:
        raise SystemExit(
            "Missing conversion dependency. Install torch, numpy, and coremltools, "
            "then rerun this script."
        ) from exc

    class ConvBlock(nn.Module):
        def __init__(self, in_ch: int, out_ch: int, kernel: int = 3, bn: bool = True):
            super().__init__()
            layers: list[nn.Module] = [
                nn.Conv2d(in_ch, out_ch, kernel, padding=kernel // 2)
            ]
            if bn:
                layers.append(nn.BatchNorm2d(out_ch))
            layers.append(nn.ReLU(inplace=True))
            self.block = nn.Sequential(*layers)

        def forward(self, x):
            return self.block(x)

    class CRNN(nn.Module):
        """Same architecture as the training project: CNN + 2xBiLSTM + CTC."""

        def __init__(self, num_classes: int, lstm_hidden: int = 256):
            super().__init__()
            self.cnn = nn.Sequential(
                ConvBlock(1, 64, bn=False),
                nn.MaxPool2d(2, 2),
                ConvBlock(64, 128, bn=False),
                nn.MaxPool2d(2, 2),
                ConvBlock(128, 256),
                ConvBlock(256, 256),
                nn.MaxPool2d((2, 1)),
                ConvBlock(256, 512),
                ConvBlock(512, 512),
                nn.MaxPool2d((2, 1)),
                ConvBlock(512, 512),
                nn.AdaptiveAvgPool2d((1, None)),
            )
            self.lstm = nn.LSTM(
                input_size=512,
                hidden_size=lstm_hidden,
                num_layers=2,
                batch_first=False,
                bidirectional=True,
                dropout=0.2,
            )
            self.fc = nn.Linear(lstm_hidden * 2, num_classes)
            self.log_softmax = nn.LogSoftmax(dim=2)

        def forward(self, x):
            features = self.cnn(x)
            features = features.squeeze(2)
            features = features.permute(2, 0, 1)
            out, _ = self.lstm(features)
            out = self.fc(out)
            return self.log_softmax(out)

    model = CRNN(num_classes=vocab_size, lstm_hidden=args.lstm_hidden)
    state_dict = strip_module_prefix(load_checkpoint_state(torch, checkpoint_path))
    model.load_state_dict(state_dict, strict=True)
    model.eval()

    example = torch.rand(1, 1, args.height, args.width, dtype=torch.float32)
    with torch.no_grad():
        traced = torch.jit.trace(model, example)
        traced = torch.jit.freeze(traced)

    target = getattr(ct.target, args.deployment_target)
    mlmodel = ct.convert(
        traced,
        convert_to="mlprogram",
        minimum_deployment_target=target,
        inputs=[
            ct.TensorType(
                name="line_image",
                shape=example.shape,
                dtype=np.float32,
            )
        ],
        outputs=[ct.TensorType(name="log_probs", dtype=np.float32)],
    )

    mlmodel.short_description = (
        "CRNN line OCR model for printed Church Slavonic text. "
        "Input is one grayscale line image."
    )
    mlmodel.input_description["line_image"] = (
        f"Float32 grayscale tensor [1, 1, {args.height}, {args.width}], "
        "pixels normalized to [0, 1]."
    )
    mlmodel.output_description["log_probs"] = (
        "CTC log probabilities with shape [time, batch, vocab_size]."
    )
    mlmodel.author = "OCR Church Slavonic dissertation project"
    mlmodel.user_defined_metadata.update({
        "source_checkpoint": checkpoint_path.name,
        "vocab_size": str(vocab_size),
        "input_height": str(args.height),
        "input_width": str(args.width),
        "decoder": "ctc_greedy_blank_0",
        "cer": "0.029",
        "wer": "0.139",
        "diacritic_accuracy": "0.885",
    })

    if output_path.exists():
        if output_path.is_dir():
            shutil.rmtree(output_path)
        else:
            output_path.unlink()
    mlmodel.save(output_path)
    print(f"Core ML package saved: {output_path}")


if __name__ == "__main__":
    main()
