# 航空機ターボエンジンの残存耐用時間（RUL）予測
Copyright 2021 Michio Inoue

実行内容（前処理、学習、予測）については
[RULPrediction_full.md](./RULPrediction_full.md)
を確認ください。

# 環境

- OS: Microsoft Windows 10 Enterprise Version 10.0 (Build 19042)
- CPU: Intel(R) Core(TM) i7-8650U CPU @ 1.90GHz   2.11 GHz
- RAM: 16.0 GB

# 使用ツール

   -  MATLAB R2021a (9.10.0.1602886)
   -  Machine Learning and Statistics Toolbox 
   -  Optimization Toolbox
   -  Parallel Computing Toolbox (Recommended) 

# 乱数シードなどの設定値の情報。

`RULPrediction_train.mlx` 内の以下のコードで

> rng(0); % 乱数シード固定（再現用）

で設定しています。


# モデルの学習から予測まで行う際のソースコードの実行手順

詳細は [entry_points.md](./entry_points.md) を確認。
カレントディレクトリをスクリプトがある `./code` に移動した上で実行ください。

```matlab
run('loadData.mlx')
run('RULPrediction_preprocess.mlx')
run('RULPrediction_train.mlx')
run('RULPrediction_predict.mlx')
```

# 学習済みモデルを使用して予測のみ行う場合のソースコードの実行手順

上の手順で生成されるファイルはそれぞれ

- データ（`xxxx.mat`）は `PROCESSED_DATA_DIR`
- トレーニングデータの特徴量 `xxx.mat` は `PROCESSED_DATA_DIR`
- テストデータの特徴量 `test.mat` は `PROCESSED_DATA_DIR`
- 予測モデル `model.mat` は `MODEL_DIR`

に事前に保存していますので、以下のスクリプトを実行することで予測のみを実施可能です。
カレントディレクトリをスクリプトがある `./code` に移動した上で実行ください。

> run('RULPrediction_predict.mlx')

詳細は [entry_points.md](./entry_points.md) を確認

# コードが実行時に前提とする条件

`RAW_DATA_DIR`（settings.jsonで指定）に `test.csv`、`train.csv` 、
そして `RAW_DATA_DIR` 以下の `/train/` にトレーニングデータ、`/test/` にテストデータがあることを想定しています。

# コードの重要な副作用

```matlab
run('loadData.mlx')
run('RULPrediction_preprocess.mlx')
run('RULPrediction_train.mlx')
```

は事前に保存している以下のファイルを上書きします。

- ファイル名・作曲家情報などのデータ（`train.mat`）in `PROCESSED_DATA_DIR`
- トレーニングデータの特徴量 `trainFeatures.mat` in `PROCESSED_DATA_DIR`
- テストデータの特徴量 `testFeatures.mat` in `PROCESSED_DATA_DIR`
- 予測モデル `modelknn.mat` in `MODEL_DIR`

