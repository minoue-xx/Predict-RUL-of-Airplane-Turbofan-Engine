# 実行手順

カレントディレクトリをスクリプトがある `./code` に移動してください。
MATLAB のコマンドウィンドウでそれぞれ run コマンドにより実行できますが、
各ライブスクリプト（`.mlx`）を開いてから実行ボタンを押す方がわかりやすいかもしれません。

RAW_DATA_DIR（settings.jsonで指定）に `test.csv`、`train.csv` 、そして `./train/` にトレーニングデータ、`./test/` にテストデータがあることを想定しています。

## 前処理 part 1

```matlab
> run('DataExploration.mlx')
```

RAW_DATA_DIR からトレーニングデータを読み取り、ファイル名・作曲家情報などのデータ（`trainDataSummary.mat`）を PROCESSED_DATA_DIR（settings.jsonで指定）に保存

## 前処理 part 2

```matlab
> run('DivideTestFiles.mlx')
> run('DivideTrainFiles.mlx')
```

RAW_DATA_DIR のトレーニングデータ・テストデータを
分割してそれぞれ TRAIN_PROCESSED_DIR と TEST_PROCESSED_DIR（settings.jsonで指定）
に保存。

## 前処理 part 3

```matlab
> run('MusicComposerClassification_preprocess.mlx')
```
上で分割したファイルに対して特徴量抽出処理を行い結果（`trainFeatures.mat` と `testFeatures.mat`）
を PROCESSED_DATA_DIR に保存。

## 学習

```matlab
> run('MusicComposerClassification_train.mlx')
```

PROCESSED_DATA_DIR の `trainFeatures.mat` を読み込みモデルの学習を行い、
モデル（`modelknn.mat`）を MODEL_DIR に保存（settings.jsonで指定）


## 予測

```matlab
> run('MusicComposerClassification_predict.mlx')
```

PROCESSED_DATA_DIR の `testFeatures.mat`、MODEL_DIR からモデル（`modelknn.mat`）
読み込み、モデルを使用して新しいサンプルの予測を実行し予測をSUBMISSION_DIR（settings.jsonで指定）に保存。