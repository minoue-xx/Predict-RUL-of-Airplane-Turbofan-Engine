# クラシック音楽の作曲家分類


Copyright 2020 Michio Inoue


# 基本方針

   1.  前処理済み（`DivideTrainFiles.mlx`, `DivideTestFiles.mlx`）を想定 
   1.  学習量音源は各ファイルから 20 秒分 最大 8 つ切り出したものを使用 
   1.  ただ、データ量が少ない 'grieg' （8ファイル）は各ファイル最大 128 個まで、 'wagner' (14ファイル)は各ファイル最大 73 個（128/14*8）までとする。 
   1.  テスト量音源については単純に冒頭から 20 秒づつ分割したものを使用して、最終的な予測結果はそれぞれの予測結果の多数決をとる。 

## 使用したツール

   -  MATLAB R2020b 
   -  Audio Toolbox 
   -  Signal Processing Toolbox 
   -  Machine Learning and Statistics Toolbox 
   -  Parallel Computing Toolbox (Recommended) 

## 手法


サンプルプログラム：[Music Genre Classification Using Wavelet Time Scattering](https://jp.mathworks.com/help/wavelet/ug/music-genre-classification-using-wavelet-scattering.html) と同じ手法を使用します。ほぼそのままなので詳細はリンク先を確認ください。


### サンプルプログラムについてまとめ

   1.  ジャズやクラシックなど10種類のジャンル分類をする課題 
   1.  音源は30秒間のファイル 
   1.  特徴量は Walet Scattering 係数（冒頭の 約 23 秒間だけ使用） 
   1.  機械学習は SVM を使用 
   1.  1つの音源から複数の特徴量を計算、それぞれ分類。最終的なラベルは多数決で決定。 

### このコードでの変更点

   1.  音源の長さは様々なので、それぞれのファイルから 20 秒間だけ切り出したものを使用（簡単のため） 
   1.  特徴量は例題通り（簡単のため） 
   1.  機械学習には kNN を使用（簡単のため） 
   1.  kNN のハイパーパラメータは一部のデータを使用したベイズ最適化で求めた（distance = cityblock, numNeighbors = 1） 


```matlab:Code
clear
```



ディレクトリ情報の確保



```matlab:Code
settings = jsondecode(fileread('..\settings.json'))
```


```text:Output
settings = 
           RAW_DATA_DIR: '../data/'
     PROCESSED_DATA_DIR: '../data/processed/'
    TRAIN_PROCESSED_DIR: '../data/processed/train'
     TEST_PROCESSED_DIR: '../data/processed/test'
              MODEL_DIR: '../models/'
         SUBMISSION_DIR: '../submissions/'

```

# データ読み込み準備＋ラベル付け


audioDatastore を使います。学習用・検証用データを分割する際に、各ラベル毎にほぼ同じ割合（8:2）で分けるために以下のステップで行います。



   1.  元データのラベルを使用し audioDatastore を作成 
   1.  splitEachLabel メソッド で 8:2 に分割したリストを作成 
   1.  リストのファイル番号をもとに分割された音データに対して新たに audioDatastore を作成 

## 元データのラベルを使用し audioDatastore を作成

```matlab:Code
location = fullfile(settings.RAW_DATA_DIR, 'train');

% 元データへの audioDatastore
adsOrig = audioDatastore(location);
% ファイルへの絶対パスリストからファイル名取得
filename = string(regexp(adsOrig.Files,'(\d*.mp3)','tokens'));
% train.csv から各ファイルのラベル情報読み込み
labelData = readtable(fullfile(settings.RAW_DATA_DIR, 'train.csv'));
% ファイル名は string 型に変更
labelData.filename = string(labelData.filename);

% filename にラベル情報をマージ
tmp = join(table(filename),labelData,'Keys','filename');
% audioDatastore に label 情報付加
adsOrig.Labels = tmp.artist
```


```text:Output
adsOrig = 
  audioDatastore のプロパティ:

                       Files: {
                              ' ...\competition\toshare\classifyClassicMusicComposer\data\train\0.mp3';
                              ' ...\competition\toshare\classifyClassicMusicComposer\data\train\1.mp3';
                              ' ...\competition\toshare\classifyClassicMusicComposer\data\train\10.mp3'
                               ... and 423 more
                              }
                     Folders: {
                              ' ...\Desktop\competition\toshare\classifyClassicMusicComposer\data\train'
                              }
                      Labels: {'bach'; 'debussy'; 'handel' ... and 423 more}
    AlternateFileSystemRoots: {}
              OutputDataType: 'double'
      SupportedOutputFormats: ["wav"    "flac"    "ogg"    "mp4"    "m4a"]
         DefaultOutputFormat: "wav"

```

# splitEachLabel メソッド で 8:2 に分割したリストを作成

```matlab:Code
rng(100); % 乱数シード固定（再現用）
adsOrig = shuffle(adsOrig); % データ順シャッフル
```



学習用と検証用に 8:2 で分割。



```matlab:Code
[adsOrigTrain,adsOrigTest] = splitEachLabel(adsOrig,0.8);
```



各ラベルのデータ数は以下の通り。



```matlab:Code
countEachLabel(adsOrigTrain)
```

| |Label|Count|
|:--:|:--:|:--:|
|1|bach|30|
|2|bartok|20|
|3|beethoven|23|
|4|brahms|32|
|5|chopin|37|
|6|debussy|24|
|7|grieg|6|
|8|handel|23|
|9|mendelssohn|14|
|10|mozart|26|
|11|rachmaninov|19|
|12|schumann|29|
|13|tchaikovsky|22|
|14|verdi|22|


```matlab:Code
countEachLabel(adsOrigTest)
```

| |Label|Count|
|:--:|:--:|:--:|
|1|bach|8|
|2|bartok|5|
|3|beethoven|6|
|4|brahms|8|
|5|chopin|9|
|6|debussy|6|
|7|grieg|2|
|8|handel|6|
|9|mendelssohn|4|
|10|mozart|7|
|11|rachmaninov|5|
|12|schumann|7|
|13|tchaikovsky|6|
|14|verdi|6|



分割後の各データを分割するために、学習用・検証用それぞれに選ばれたファイルの番号だけを確保しておきます。



```matlab:Code
idTrain = string(regexp(string(adsOrigTrain.Files),'(\d*).mp3','tokens'));
idTest = string(regexp(string(adsOrigTest.Files),'(\d*).mp3','tokens'));
```

# 分割された音データを分割して新たに audioDatastore を作成


より効率の良いやり方があるとおもいますが、audioDatastore に絶対パスと対応するラベルのリストをマニュアルでつける作業します。1-1.mp4, 1-2.mp4, 1-3.mp4 同じファイルから分割されているものがセットで分割されるようにしています。1-1.mp4 が学習用、1-2.mp4 が検証用に分かれていると、同じ楽曲が学習用・検証用に含まれることになりモデルの性能評価として適切ではない可能性があるため。


## 学習用データへの audioDatastore を作成しファイルの数を確認

```matlab:Code
tmp = fullfile(settings.TRAIN_PROCESSED_DIR, idTrain + "-*.mp4");
adsTrain = audioDatastore(tmp);
% ファイル番号部分だけリスト化
fileidTrain = string(regexp(string(adsTrain.Files),'(\d*)-\d*.mp4','tokens'));

% 元ファイルの番号取得
fileid = string(regexp(adsOrig.Files,'(\d*).mp3','tokens')); 
% adsOrig のファイル番号と突き合わせて
[~,idxTrain] = ismember(fileidTrain,fileid);
% ラベル名を付与
adsTrain.Labels = adsOrig.Labels(idxTrain);
% 各ラベルのファイル数カウント
countEachLabel(adsTrain)
```

| |Label|Count|
|:--:|:--:|:--:|
|1|bach|143|
|2|bartok|160|
|3|beethoven|182|
|4|brahms|249|
|5|chopin|220|
|6|debussy|178|
|7|grieg|102|
|8|handel|145|
|9|mendelssohn|112|
|10|mozart|208|
|11|rachmaninov|152|
|12|schumann|232|
|13|tchaikovsky|164|
|14|verdi|176|

## 同様に検証用データへの audioDatastore を作成しファイルの数を確認

```matlab:Code
tmp = fullfile(settings.TRAIN_PROCESSED_DIR, idTest + "-*.mp4");
adsTest = audioDatastore(tmp);
% ファイル番号部分だけリスト化
fileidTest = string(regexp(string(adsTest.Files),'(\d*)-\d*.mp4','tokens'));
 % adsOrig のファイル番号と突き合わせて
[~,idxTest] = ismember(fileidTest,fileid);
 % ラベル名を付与
adsTest.Labels = adsOrig.Labels(idxTest);
% 各ラベルのファイル数カウント
countEachLabel(adsTest)
```

| |Label|Count|
|:--:|:--:|:--:|
|1|bach|37|
|2|bartok|40|
|3|beethoven|48|
|4|brahms|62|
|5|chopin|61|
|6|debussy|44|
|7|grieg|23|
|8|handel|42|
|9|mendelssohn|32|
|10|mozart|56|
|11|rachmaninov|40|
|12|schumann|56|
|13|tchaikovsky|48|
|14|verdi|48|

# 特徴量計算


詳細は `helperscatfeatures.m` を参照。例題は 22.05 Hz の音源で今回は 44.1 Hz だが、変わらず 2^19 点使用することにする。`helperscatfeatures` のソース はこちら。学習データとテスト データの両方のウェーブレット散乱特徴量を計算します。



```matlab:Code(Display)
function features = helperscatfeatures(x,sf)
% This function is in support of wavelet scattering examples only. It may
% change or be removed in a future release.

features = featureMatrix(sf,x(1:2^19),'Transform','log');
features = features(:,1:8:end)';
end
```



tall 配列を使用



```matlab:Code
Ttrain = tall(adsTrain);
Ttest = tall(adsTest);
```



Wavelet time scattering decomposition framework の定義



```matlab:Code
sf = waveletScattering('SignalLength',2^19,'SamplingFrequency',44100,...
    'InvarianceScale',0.5);
scatteringTrain = cellfun(@(x)helperscatfeatures(x,sf),Ttrain,'UniformOutput',false);
scatteringTest = cellfun(@(x)helperscatfeatures(x,sf),Ttest,'UniformOutput',false);
```



学習データの散乱特徴量を計算して行列にすべての特徴量をまとめます。この処理には時間がかかります。



```matlab:Code
TrainFeatures = gather(scatteringTrain);
```


```text:Output
並列プール 'local' を使用して tall 式を評価中:
- パス 1/1: 53 分 31 秒 で完了
53 分 31 秒 で評価が完了しました
```


```matlab:Code
TrainFeatures = cell2mat(TrainFeatures);
```



検証データでも同様に処理。



```matlab:Code
TestFeatures = gather(scatteringTest);
```


```text:Output
並列プール 'local' を使用して tall 式を評価中:
- パス 1/1: 13 分 50 秒 で完了
13 分 50 秒 で評価が完了しました
```


```matlab:Code
TestFeatures = cell2mat(TestFeatures);
```



`TrainFeatures` と `TestFeatures` は各20秒のファイルあたり 418 の変数、16 個ずつの特徴量が計算されます。3098 個の学習データ数から作られる特徴量行列は 49568 x 418、検証データ（773個）の散乱特徴量行列は 12368 x 418 です。学習データのラベルも作成します。



```matlab:Code
numTimeWindows = 16;
trainLabels = adsTrain.Labels;
numTrainSignals = numel(trainLabels);
trainLabels = repmat(trainLabels,1,numTimeWindows);
trainLabels = reshape(trainLabels',numTrainSignals*numTimeWindows,1);
```



検証データでも同様に処理



```matlab:Code
testLabels = adsTest.Labels;
numTestSignals = numel(testLabels);
testLabels = repmat(testLabels,1,numTimeWindows);
testLabels = reshape(testLabels',numTestSignals*numTimeWindows,1);
```



いったんデータを保存。



```matlab:Code
trainFeaturesFilename = fullfile(settings.PROCESSED_DATA_DIR, 'trainFeatures.mat');
save(trainFeaturesFilename,'TrainFeatures','trainLabels','TestFeatures','testLabels',...
    'numTrainSignals','numTestSignals','adsTest','adsTrain');
```

# モデル学習


TrainFeatures と TestFeatures を使って[分類学習器](https://jp.mathworks.com/help/stats/classification-learner-app.html)アプリで適当なアルゴリズムをベイズ最適化によって決定。




ここでは比較的精度も良く学習時間も短い最近傍法 (k=1) で距離尺度は cityblock を使用します。




計算時間を短縮するため PCA で 95% の分散を説明することができる主成分数に絞ります。




詳細はアプリから自動生成した trainClassifier.m を確認。



```matlab:Code
trainFeaturesFilename = fullfile(settings.PROCESSED_DATA_DIR, 'trainFeatures.mat');
load(trainFeaturesFilename,'TrainFeatures','trainLabels','TestFeatures','testLabels','adsTest');
trainingData = TrainFeatures;
responseData = trainLabels;

trainedClassifier = trainClassifier(trainingData, responseData);
```

# 精度検証


検証用データを使って予測結果を確認します。まずは 773 x 16 = 12368 個の結果（個別の特徴量に対する結果）。



```matlab:Code
predLabels = trainedClassifier.predictFcn(TestFeatures);
f = figure(1);
f.Position = [149.8000  204.2000  766.4000  556.8000];
confusionchart(testLabels,predLabels,...
    'ColumnSummary','column-normalized', ...
    'RowSummary','row-normalized');
```


![figure_0.png](MusicComposerClassification_full_images/figure_0.png)

## 多数決


1つのファイルから 16 セットの特徴量を作っているので、16個の予測結果から多数決をもって最終的なラベルを求めます。詳細は `helperMajorityVote.m` を確認。[ウェーブレット時間散乱を使用した音楽ジャンルの分類](https://jp.mathworks.com/help/signal/examples/music-genre-classification-using-wavelet-scattering.html)で使われている `helperMajorityVote.m` は同じ得票数のラベルがあった場合には `NoUniqueMode` という結果を返すが、この部分は使用しない（必ず何らかの結果を返す）



```matlab:Code
classes = categorical(trainedClassifier.ClassificationKNN.ClassNames);
[TestVotes,TestCounts] = helperMajorityVote(predLabels,adsTest.Labels,classes);

f = figure(2);
f.Position = [149.8000  204.2000  766.4000  556.8000];
confusionchart(categorical(adsTest.Labels),TestVotes,...
    'ColumnSummary','column-normalized', ...
    'RowSummary','row-normalized');
```


![figure_1.png](MusicComposerClassification_full_images/figure_1.png)



wagner, grieg などデータ数が少ないラベルの予測精度がいまいちな傾向にあります。


# テストデータ（提出用）の予測


学習データ＋検証用データで再学習したのち、テスト用データ（提出用）の予測を同様におこないます。



```matlab:Code
trainingData = [TrainFeatures; TestFeatures];
responseData = [trainLabels; testLabels];

trainedClassifier = trainClassifier(trainingData, responseData);
modelFilename = fullfile(settings.MODEL_DIR,'modelknn.mat');
save(modelFilename,'trainedClassifier');
```

# テストデータからの特徴量計算


学習用・検証用と同様に処理。



```matlab:Code
ads = audioDatastore(settings.TEST_PROCESSED_DIR); 
Ttest = tall(ads);
scatteringTest = cellfun(@(x)helperscatfeatures(x,sf),Ttest,'UniformOutput',false);

TestFeatures = gather(scatteringTest);
TestFeatures = cell2mat(TestFeatures);
```



いったん保存



```matlab:Code
testFeaturesFilename = fullfile(settings.PROCESSED_DATA_DIR, 'testFeatures.mat');
save(testFeaturesFilename,'TestFeatures','ads')
```

# テストデータの予測


上で学習した予測モデルを使用して多数決を取ります。



```matlab:Code
modelFilename = fullfile(settings.MODEL_DIR,'modelknn.mat');
testFeaturesFilename = fullfile(settings.PROCESSED_DATA_DIR, 'testFeatures.mat');

load(modelFilename,'trainedClassifier')
load(testFeaturesFilename,'TestFeatures','ads')
predLabels = trainedClassifier.predictFcn(TestFeatures);
```


```matlab:Code
% カテゴリ型から数値に変換する際に対応付けられるよう順番付けておきます。
% double(categori) - 1 で対応する数値に変換できます。
valueset = {'brahms','debussy','bach','mendelssohn','schumann',...
    'handel','verdi','beethoven','bartok','chopin','rachmaninov',...
    'mozart','grieg','tchaikovsky','wagner'};
classes = categorical(trainedClassifier.ClassificationKNN.ClassNames,valueset);

% 多数決を取る
[TestVotes,TestCounts] = helperMajorityVote(predLabels,ads.Files,classes);
```

# 結果をファイルに出力


ファイルの順番は特に関係ない（提出して確認済み）



```matlab:Code
[~,filename,~] = fileparts(ads.Files);
filename = string(filename) + ".mp3";

artist_id = double(TestVotes)-1;
results = table(filename,artist_id);

ids = string(regexp(filename,'(\d*)-\d*.mp3','tokens'));
results.ids = ids;
modeResults = groupsummary(results,'ids','mode','artist_id');

modeResults = removevars(modeResults,'GroupCount');
modeResults.Properties.VariableNames{1} = 'filename';
modeResults.Properties.VariableNames{2} = 'artist_id';
modeResults.filename = modeResults.filename + ".mp3";
submissionFilename = fullfile(settings.SUBMISSION_DIR,'results.csv');
writetable(modeResults,submissionFilename);
```

