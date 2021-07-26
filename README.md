# クラシック音楽の作曲家分類
Copyright 2020 Michio Inoue

実行内容（前処理、学習、予測）については
[MusicComposerClassification_full.md](./MusicComposerClassification_full.md)
を確認ください。

# 環境

- OS: Microsoft Windows 10 Enterprise Version 10.0 (Build 19042)
- CPU: Intel(R) Core(TM) i7-8650U CPU @ 1.90GHz   2.11 GHz
- RAM: 16.0 GB

# 使用ツール

   -  MATLAB R2020b (9.9.0.1467703)
   -  Audio Toolbox 
   -  Signal Processing Toolbox 
   -  Machine Learning and Statistics Toolbox 
   -  Parallel Computing Toolbox (Recommended) 

# 乱数シードなどの設定値の情報。

`MusingComposerClassification_preprocess.mlx` 内の以下のコードで

> rng(100); % 乱数シード固定（再現用）

で設定しています。


# モデルの学習から予測まで行う際のソースコードの実行手順

詳細は [entry_points.md](./entry_points.md) を確認。
カレントディレクトリをスクリプトがある `./code` に移動した上で実行ください。

```matlab
run('DataExploration.mlx')
run('DivideTestFiles.mlx')
run('DivideTrainFiles.mlx')
run('MusicComposerClassification_preprocess.mlx')
run('MusicComposerClassification_train.mlx')
run('MusicComposerClassification_predict.mlx')
```

# 学習済みモデルを使用して予測のみ行う場合のソースコードの実行手順

上の手順で生成されるファイルはそれぞれ

- ファイル名・作曲家情報などのデータ（`trainDataSummary.mat`）は `PROCESSED_DATA_DIR`
- トレーニングデータの特徴量 `trainFeatures.mat` は `PROCESSED_DATA_DIR`
- テストデータの特徴量 `testFeatures.mat` は `PROCESSED_DATA_DIR`
- 予測モデル `modelknn.mat` は `MODEL_DIR`

に事前に保存していますので、以下のスクリプトを実行することで予測のみを実施可能です。
カレントディレクトリをスクリプトがある `./code` に移動した上で実行ください。

> run('MusicComposerClassification_predict.mlx')

詳細は [entry_points.md](./entry_points.md) を確認

# コードが実行時に前提とする条件

`RAW_DATA_DIR`（settings.jsonで指定）に `test.csv`、`train.csv` 、
そして `RAW_DATA_DIR` 以下の `/train/` にトレーニングデータ、`/test/` にテストデータがあることを想定しています。

# コードの重要な副作用

```matlab
run('DataExploration.mlx')
run('DivideTestFiles.mlx')
run('DivideTrainFiles.mlx')
run('MusicComposerClassification_preprocess.mlx')
run('MusicComposerClassification_train.mlx')
```

は事前に保存している以下のファイルを上書きします。

- ファイル名・作曲家情報などのデータ（`trainDataSummary.mat`）in `PROCESSED_DATA_DIR`
- トレーニングデータの特徴量 `trainFeatures.mat` in `PROCESSED_DATA_DIR`
- テストデータの特徴量 `testFeatures.mat` in `PROCESSED_DATA_DIR`
- 予測モデル `modelknn.mat` in `MODEL_DIR`

