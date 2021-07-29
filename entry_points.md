# 実行手順

カレントディレクトリをスクリプトがある `./code` に移動してください。
MATLAB のコマンドウィンドウでそれぞれ run コマンドにより実行できますが、
各ライブスクリプト（`.mlx`）を開いてから実行ボタンを押す方がわかりやすいかもしれません。

`RAW_DATA_DIR`（settings.jsonで指定）以下の `/train/` に
トレーニングデータ (`train_*.csv`)、`/test/` にテストデータ (`test_*.csv`) があることを想定しています。

## 前処理 part 1

```matlab
> run('loadData.mlx')
```

RAW_DATA_DIR からデータ (`train_*.csv`, `test_*.csv`)を読み取り、
元データを整形したデータ（`train_*_.mat`, `train_*Unwrap_.mat`, 
`test_*_.mat`, `test_*Unwrap_.mat`）
を `PROCESSED_DATA_DIR`（settings.jsonで指定）に保存

## 前処理 part 2

```matlab
> run('RULPrediction_preprocess.mlx')
```

上で整形したデータ（`train_*_.mat`, `train_*Unwrap_.mat`, 
`test_*_.mat`, `test_*Unwrap_.mat`）から使用するデータだけを
取り出した（`train_*Unwrap_OtherParam.mat', 
`test_*Unwrap_OtherParam.mat'）を `PROCESSED_DATA_DIR` に保存し、
さらに追加処理をしてトレーニングデータの特徴量 `trainData.mat` 
とテストデータの特徴量 `testData.mat` を `PROCESSED_DATA_DIR` に保存。


## 学習

```matlab
> run('RULPrediction_train.mlx')
```

PROCESSED_DATA_DIR の `trainData.mat` を読み込みモデルの学習を行い、
モデル（`model.mat`）を `MODEL_DIR` に保存（settings.jsonで指定）


## 予測

```matlab
> run('RULPrediction_predict.mlx')
```

`PROCESSED_DATA_DIR` の `testFeatures.mat`、`MODEL_DIR` からモデル（`model.mat`）
読み込み、モデルを使用して新しいサンプルの予測を実行し予測結果（submission.csv）を `SUBMISSION_DIR`（settings.jsonで指定）に保存。