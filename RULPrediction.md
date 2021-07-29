# 航空機ターボエンジンの残存耐用時間（RUL）予測

Copyright 2021 Michio Inoue

このコードでは論文で Model Health Parameters と紹介されている変数と、エンジンの状態評価に使用される変数として次の４つも使用する。T48, SmFan, SmLPC, SmHPC

At present, the N-CMAPSS dataset contains eight sets of data from 128 units and seven different failure modes affecting the flow (F) and/or efficiency (E) of all the rotating sub-components. Table 2 provides an overview of flight classes and failure modes for each of the sets of data provided 

とある通り、DS 番号によって入れ込まれている故障モードは様々なようなので、それぞれで挙動が異なることが想定される。変数名の一覧は以下の通り。

   1.  fan_eff_mod: Fan efficiency modifier (-) 
   1.  fan_flow_mod: Fan flow modifier (-) 
   1.  LPC_eff_mod: LPC efficiency modifier (-) 
   1.  LPC_flow_mod: LPC flow modifier (-) 
   1.  HPC_eff_mod: HPC efficiency modifier (-) 
   1.  HPC_flow_mod: HPC flow modifier (-) 
   1.  HPT_eff_mod: HPT efficiency modifier (-) 
   1.  HPT_flow_mod: HPT flow modifier (-) 
   1.  LPT_eff_mod: LPT efficiency modifier (-) 
   1.  LPT_flow_mod: LPT flow modifier (-) 

# 事前準備

ディレクトリ情報の確保

```matlab:Code
clear
settings = jsondecode(fileread('../settings.json'));
datadir = settings.PROCESSED_DATA_DIR
```

```text:Output
datadir = '../data/processed/'
```

```matlab:Code
modeldir = settings.MODEL_DIR
```

```text:Output
modeldir = '../models/'
```

```matlab:Code
subdir = settings.SUBMISSION_DIR
```

```text:Output
subdir = '../submissions/'
```

DS (Data Set?) 名定義

```matlab:Code
fileID = ["DS01-005", "DS02-006", "DS03-012", "DS04", "DS05", ...
    "DS06", "DS07", "DS08a-009", "DS08c-008"];
```

変数名: 各 cycle での平均値を使用するので、平均値の変数名定義

```matlab:Code
eff_mod_list = ["fan_eff_mod";"fan_flow_mod";"LPC_eff_mod";"LPC_flow_mod";...
    "HPC_eff_mod";"HPC_flow_mod";"HPT_eff_mod";"HPT_flow_mod";
    "LPT_eff_mod";"LPT_flow_mod"];
meaneff_mod_list = "mean" + eff_mod_list;

% 追加で使用する変数も４つ追加（エンジンの状態評価に使用される変数）
var_list = [eff_mod_list; "T48";"SmFan";"SmLPC";"SmHPC"];
meanvar_list = "mean" + var_list;
```

# 平均値計算

事前にデータは cycle 単位で分割し保存しているとします。loadData.mlx 参照。ここではさらに各 Model Health Parameter の cycle 単位での平均値を計算してデータ保存しておきます。

```matlab:Code
% 一度作成すればOK
if ~exist(fullfile(datadir, "train_DS01-005Unwrap_OtherParam.mat"),'file')
    % 各fileID毎に処理
    for ii=1:length(fileID) % 1 min
        load(fullfile(datadir, "train_" + fileID(ii) + "Unwrap.mat"),"dTrainUnwrap");
        % Unit 毎に処理
        for jj=1:height(dTrainUnwrap)
            dUnit = dTrainUnwrap.data{jj};

            % 平均値計算
            for kk=1:length(var_list)
                dUnit.("mean" + var_list(kk)) ...
                    = cellfun(@(x) mean(x.(var_list(kk))), dUnit.data);
            end
            dUnit = removevars(dUnit,'data'); % 元時系列データは重いので削除
            dTrainUnwrap.data{jj} = dUnit;
        end
        % 保存
        save(fullfile(datadir, "train_" + fileID(ii) + "Unwrap_OtherParam.mat"),"dTrainUnwrap");

        % test データでも同様に処理
        load(fullfile(datadir, "test_" + fileID(ii) + "Unwrap.mat"),"dTestUnwrap");
        % Unit 毎に処理
        for jj=1:height(dTestUnwrap)
            dUnit = dTestUnwrap.data{jj};

            % 平均値計算
            for kk=1:length(var_list)
                dUnit.("mean" + var_list(kk)) ...
                    = cellfun(@(x) mean(x.(var_list(kk))), dUnit.data);
            end
            tmp = dUnit{:,6:end};
            dUnit = removevars(dUnit,'data'); % 元時系列データは重いので削除
            dTestUnwrap.data{jj} = dUnit;
        end
        % 保存
        save(fullfile(datadir, "test_" + fileID(ii) + "Unwrap_OtherParam.mat"),"dTestUnwrap");

    end
end
```

# 特徴量作成

以下でモデル学習に使用するためのデータを作成するが以下の点に注意。

   1.  Model Health Parameter は DS によって値を持つ変数が異なることが論文に記載されている。ただ DS02-006 の Unit 2, 5, 10 については１つの Health Parameter だけに変動が見られ、DS01-005 と同じ様相であるため、変数 DS は DS01-005 とする。 
   1.  また RUL が 100 である unit は、100 回目の実験で打ち切られた（すなわちまだ寿命ではない）データである可能性があるため、Fc = 1 のケース（本来寿命が長くなりがちのケース）で RUL = 100 のデータは学習データから取り除く。 
   1.  その他 Health Parameter の値については移動平均で滑らかにする、初期変動分を調整する、abnormal degredation 時（hs = 0）の傾きだけを別途評価するための変数を作成するなどの処理をする。 

```matlab:Code
trainData = [];
testData = [];
% fileID (DS) 毎に処理
for ii=1:length(fileID)
    % 処理ずみのデータを読み込み
    load(fullfile(datadir, "train_" + fileID(ii) + "Unwrap_OtherParam.mat"),"dTrainUnwrap");

    % Unit 毎に処理
    for jj=1:height(dTrainUnwrap)
        dUnit = dTrainUnwrap.data{jj};

        % 学習データから取り除く
        if height(dUnit) == 100 && unique(dUnit.Fc) == 1
            continue
        end

        dUnit.DS = repmat(fileID(ii),height(dUnit),1);
        dUnit.Unit = repmat(dTrainUnwrap.unit(jj),height(dUnit),1);

        % DS02-006 の unit = 2,5,10 は DS01-005 として取り扱う
        if unique(dUnit.DS == 'DS02-006') && ...
                (dUnit.Unit(1) == 2 || dUnit.Unit(1) == 5 || dUnit.Unit(1) == 10)
            dUnit.DS = repmat(fileID(1),height(dUnit),1);
        end

        % meaneff_mod_list の変数について手を加える
        tmp = dUnit{:,meaneff_mod_list};
        tmp = movmean(tmp,5); % 移動平均

        % 初期変動を取り除く処理（線形近似をして切片分を調整）
        for kk=1:size(tmp,2)
            p = polyfit(1:10,tmp(1:10,kk),1);
            tmp(:,kk) = tmp(:,kk) - p(2);
        end

        % 全 DS 間で比べられるよう統合指標作成（ざっくり第一主成分）
        [~,scores,~] = pca(tmp);

        dUnit{:,meaneff_mod_list} = tmp;
        dUnit.score1 = scores(:,1)-scores(1,1);

        % abnormal degregation の傾きを評価
        % ここでは test data に合わせて、40 cycle 目までのデータを使用
        idxh0init = find(dUnit.hs == 0,1);
        idxh0fint = find(dUnit.cycle == 40,1);
        x = dUnit.cycle(idxh0init-3:idxh0fint);
        y = dUnit.score1(idxh0init-3:idxh0fint);

        x0 = [0.002,1.5];
        opts = optimoptions('fmincon','TypicalX',x0,'Display',"none");
        p = fmincon(@(a)myfun(a,[x-x(1),y-y(1)]),x0,[],[],[],[],[0.0001,1.4],[0.003,1.6],[],opts);

        % 係数も特徴量として使用する
        dUnit.p1 = p(1)*ones(height(dUnit),1);
        dUnit.p2 = p(2)*ones(height(dUnit),1);

        dTrainUnwrap.data{jj} =  dUnit;
        dTrainUnwrap.p1(jj) = p(1);
        dTrainUnwrap.p2(jj) = p(2);

        trainData = [trainData; dUnit]; %#ok<AGROW> 

    end

    % 以下 test data に対しても同様の処理
    % 処理ずみのデータを読み込み
    load(fullfile(datadir, "test_" + fileID(ii) + "Unwrap_OtherParam.mat"),"dTestUnwrap");

    % Unit 毎に処理
    for jj=1:height(dTestUnwrap)
        dUnit = dTestUnwrap.data{jj};
        dUnit.DS = repmat(fileID(ii),height(dUnit),1);
        dUnit.Unit = repmat(dTestUnwrap.unit(jj),height(dUnit),1);

        tmp = dUnit{:,meaneff_mod_list};

        tmp = movmean(tmp,5);

        for kk=1:size(tmp,2)
            p = polyfit(1:10,tmp(1:10,kk),1);
            p(2);
            tmp(:,kk) = tmp(:,kk) - p(2);
        end

        [~,scores,~] = pca(tmp);

        dUnit{:,meaneff_mod_list} = tmp;
        dUnit.score1 = scores(:,1)-scores(1,1);

        mvscore = movmean(dUnit.score1,1);
        idxh0init = find(dUnit.hs == 0,1);
        idxh0fint = find(dUnit.cycle == 40,1);
        x = dUnit.cycle(idxh0init-3:idxh0fint);
        y = mvscore(idxh0init-3:idxh0fint);

        x0 = [0.002,1.5];
        opts = optimoptions('fmincon','TypicalX',x0,'Display',"none");
        p = fmincon(@(a)myfun(a,[x-x(1),y-y(1)]),x0,[],[],[],[],[0.0001,1.4],[0.003,1.6],[],opts);
        dUnit.p1 = p(1)*ones(height(dUnit),1);
        dUnit.p2 = p(2)*ones(height(dUnit),1);

        dTestUnwrap.data{jj} =  dUnit;
        dTestUnwrap.p1(jj) = p(1);
        dTestUnwrap.p2(jj) = p(2);
        testData = [testData; dUnit]; %#ok<AGROW> 

    end
end

```

こんな様子のデータです。

```matlab:Code
head(trainData)
```

| |cycle|Y|Fc|hs|meanfan_eff_mod|meanfan_flow_mod|meanLPC_eff_mod|meanLPC_flow_mod|meanHPC_eff_mod|meanHPC_flow_mod|meanHPT_eff_mod|meanHPT_flow_mod|meanLPT_eff_mod|meanLPT_flow_mod|meanT48|meanSmFan|meanSmLPC|meanSmHPC|DS|Unit|score1|p1|p2|
|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
|1|1|74|3|1|0|0|0|0|0|0|-2.5279e-05|0|0|0|1.6126e+03|19.0362|8.4587|28.4869|"DS01-005"|2|0|6.4915e-04|1.5996|
|2|2|73|3|1|0|0|0|0|0|0|-2.4379e-05|0|0|0|1.6790e+03|17.6942|8.6434|27.7984|"DS01-005"|2|9.0000e-07|6.4915e-04|1.5996|
|3|3|72|3|1|0|0|0|0|0|0|-7.2379e-05|0|0|0|1.6231e+03|18.4480|8.9680|28.1324|"DS01-005"|2|-4.7100e-05|6.4915e-04|1.5996|
|4|4|71|3|1|0|0|0|0|0|0|-8.5079e-05|0|0|0|1.6353e+03|18.3781|8.3492|28.3499|"DS01-005"|2|-5.9800e-05|6.4915e-04|1.5996|
|5|5|70|3|1|0|0|0|0|0|0|-1.2222e-04|0|0|0|1.6575e+03|18.5152|8.5625|27.8083|"DS01-005"|2|-9.6940e-05|6.4915e-04|1.5996|
|6|6|69|3|1|0|0|0|0|0|0|-1.7238e-04|0|0|0|1.6323e+03|19.3678|8.1389|28.6921|"DS01-005"|2|-1.4710e-04|6.4915e-04|1.5996|
|7|7|68|3|1|0|0|0|0|0|0|-2.0920e-04|0|0|0|1.6508e+03|18.7857|8.5636|27.8640|"DS01-005"|2|-1.8392e-04|6.4915e-04|1.5996|
|8|8|67|3|1|0|0|0|0|0|0|-1.9452e-04|0|0|0|1.6075e+03|19.4445|8.2486|28.5761|"DS01-005"|2|-1.6924e-04|6.4915e-04|1.5996|

保存

```matlab:Code
save(fullfile(datadir,'trainData.mat'),'trainData')
save(fullfile(datadir,'testData.mat'),'testData')
```

# モデル学習

```matlab:Code
load(fullfile(datadir,'trainData.mat'),'trainData')
load(fullfile(datadir,'testData.mat'),'testData')

% 変数選択で試行錯誤しやすいようこの形にしておく
% （ここでは unit 番号を削るのみ）
trainDSUnitID = string(trainData.DS) + string(trainData.Unit);
% 学習用
subtrainData = trainData(:,["cycle","Y",meanvar_list',"Fc","hs","DS","p1","p2","score1"]);
% テスト用
subtestData = testData(:,["cycle",meanvar_list',"Fc","hs","DS","p1","p2","score1"]);
```

## アンサンブル決定木の学習

以下のハイパーパラメータもベイズ最適化でチューニングします。

   -  [`Method`](https://www.mathworks.com/help/releases/R2021a/stats/fitrensemble.html?s_tid=doc_ta#bvcj_tw-1-Method) — 使用可能な方式は `'Bag'` または `'LSBoost'` です。 
   -  [`NumLearningCycles`](https://www.mathworks.com/help/releases/R2021a/stats/fitrensemble.html?s_tid=doc_ta#bvcj_tw-1-NumLearningCycles) — `fitrensemble` は、既定では範囲 `[10,500]` の対数スケールで、正の整数を探索します。 
   -  [`LearnRate`](https://www.mathworks.com/help/releases/R2021a/stats/fitrensemble.html?s_tid=doc_ta#mw_0b7f0d4a-2aae-4c52-a876-a6cb06c15ba4) — `fitrensemble` は、既定では範囲 `[1e-3,1]` の対数スケールで、正の実数を探索します。 
   -  [`MinLeafSize`](https://www.mathworks.com/help/releases/R2021a/stats/fitrtree.html#bt6cr84-MinLeafSize) — `fitrensemble` は、範囲 `[1,max(2,floor(NumObservations/2))]` の対数スケールで整数を探索します。 

単純に交差検定のためのデータ分割を行うだけなら 'OptimizeHyperparameters' オプションを 'auto' に設定するだけで良い（以下例）

```matlab:Code(Display)
mdl = fitrensemble(trainData,'Y','OptimizeHyperparameters','auto');
```

ただ、今回は同じ unit からのデータが学習用・検証用データ両方に存在しないように分ける必要があるので、以下のコード。

```matlab:Code
rng(0)% 乱数シード固定（再現用）
NumObservations = height(subtrainData); % データ数
NumPredictors = width(subtrainData)-1; % 説明変数の数

% ベイズ最適化でチューニングする変数の定義
Method = optimizableVariable('Method',["Bag","LSboost"],'Type','categorical');
NumLearningCycles = optimizableVariable('NumLearningCycles',[10,500],'Transform','log','Type',"integer");
LearnRate = optimizableVariable('LearnRate',[1e-3,1],'Transform','log');
MinLeafSize = optimizableVariable('MinLeafSize',[1,max(2,floor(NumObservations/2))],'Transform','log','Type',"integer");

vars = [Method,NumLearningCycles,LearnRate,MinLeafSize];

% 目的関数定義（交差検定の誤差が目的変数）
fun = @(vars) myBayesGroup(vars,subtrainData,trainDSUnitID);

% UseParallel, true で並列処理（Parallel Computing Toolbox) できるが
% 結果の再現性が失われてしまうのでここでは並列処理なし
results = bayesopt(fun,vars,'UseParallel',false,...
    'AcquisitionFunctionName',"expected-improvement-plus",...
    'MaxObjectiveEvaluations',50);
```

```text:Output
|===================================================================================================================================|
| Iter | Eval   | Objective   | Objective   | BestSoFar   | BestSoFar   |       Method | NumLearningC-|    LearnRate |  MinLeafSize |
|      | result |             | runtime     | (observed)  | (estim.)    |              | ycles        |              |              |
|===================================================================================================================================|
|    1 | Best   |      5.9987 |      1.9737 |      5.9987 |      5.9987 |      LSboost |           33 |     0.027547 |          516 |
|    2 | Accept |      7.4055 |      1.3599 |      5.9987 |      6.0745 |      LSboost |           53 |    0.0018978 |            2 |
|    3 | Best   |      4.1443 |      11.779 |      4.1443 |      4.1447 |      LSboost |          468 |     0.051433 |           32 |
|    4 | Best   |      4.0419 |      1.6909 |      4.0419 |      4.0422 |          Bag |           41 |    0.0055048 |           15 |
|    5 | Accept |      4.0496 |     0.73576 |      4.0419 |       4.042 |          Bag |           26 |       0.1601 |           51 |
|    6 | Accept |      6.3291 |     0.74193 |      4.0419 |       4.042 |          Bag |           52 |    0.0052922 |         1808 |
|    7 | Best   |      3.7037 |     0.89814 |      3.7037 |      3.7038 |          Bag |           21 |       0.2869 |           10 |
|    8 | Accept |      3.7792 |      1.2048 |      3.7037 |      3.7037 |          Bag |           28 |      0.10472 |            1 |
|    9 | Accept |      6.3229 |      5.2501 |      3.7037 |      3.7037 |      LSboost |          498 |     0.038049 |         1744 |
|   10 | Accept |      3.9092 |      11.474 |      3.7037 |      3.7037 |      LSboost |          500 |      0.12719 |            2 |
|   11 | Accept |      3.9685 |     0.53263 |      3.7037 |      3.7036 |          Bag |           10 |      0.20773 |            1 |
|   12 | Accept |      3.8643 |     0.36908 |      3.7037 |      3.7034 |          Bag |           10 |    0.0070361 |           34 |
|   13 | Accept |      3.9471 |      11.624 |      3.7037 |       3.704 |          Bag |          257 |     0.028763 |            1 |
|   14 | Accept |      4.2075 |      4.5559 |      3.7037 |       3.704 |      LSboost |          182 |      0.66974 |           14 |
|   15 | Accept |       3.865 |       1.206 |      3.7037 |      3.7045 |          Bag |           31 |     0.050186 |            9 |
|   16 | Accept |      4.3444 |      12.009 |      3.7037 |      3.7041 |      LSboost |          499 |      0.99914 |           10 |
|   17 | Accept |      4.0162 |      2.1117 |      3.7037 |      3.7041 |      LSboost |           81 |      0.14431 |            8 |
|   18 | Accept |      3.7938 |       61.63 |      3.7037 |      3.7044 |          Bag |          492 |      0.32262 |            5 |
|   19 | Accept |      3.7411 |      2.1305 |      3.7037 |      3.7042 |          Bag |           82 |       0.9649 |           26 |
|   20 | Accept |      4.0818 |      3.8106 |      3.7037 |      3.7042 |      LSboost |          166 |      0.41431 |            1 |
|===================================================================================================================================|
| Iter | Eval   | Objective   | Objective   | BestSoFar   | BestSoFar   |       Method | NumLearningC-|    LearnRate |  MinLeafSize |
|      | result |             | runtime     | (observed)  | (estim.)    |              | ycles        |              |              |
|===================================================================================================================================|
|   21 | Accept |      3.8784 |     0.94318 |      3.7037 |      3.7042 |          Bag |           29 |      0.93263 |           11 |
|   22 | Accept |      4.5997 |      1.1882 |      3.7037 |      3.7041 |          Bag |           69 |      0.98632 |          444 |
|   23 | Accept |      3.9806 |      1.0256 |      3.7037 |      3.7537 |          Bag |           25 |       0.1035 |            3 |
|   24 | Accept |      3.7588 |      6.7736 |      3.7037 |      3.7416 |          Bag |          254 |      0.43515 |           18 |
|   25 | Accept |      3.7796 |     0.95594 |      3.7037 |      3.7548 |          Bag |           22 |    0.0010054 |            1 |
|   26 | Accept |      3.9478 |      5.8742 |      3.7037 |      3.7642 |          Bag |          188 |     0.001002 |            9 |
|   27 | Accept |      4.0271 |     0.56381 |      3.7037 |      3.7526 |          Bag |           12 |    0.0028452 |            1 |
|   28 | Accept |      3.9811 |      7.2851 |      3.7037 |      3.8186 |          Bag |          256 |        0.356 |           14 |
|   29 | Accept |      3.8764 |       14.24 |      3.7037 |       3.823 |          Bag |          357 |      0.94921 |            1 |
|   30 | Accept |      3.9112 |      0.5595 |      3.7037 |      3.8265 |          Bag |           15 |      0.97107 |            8 |
|   31 | Accept |      3.8338 |      19.237 |      3.7037 |      3.8258 |          Bag |          482 |    0.0010033 |            1 |
|   32 | Accept |      3.9882 |      6.5122 |      3.7037 |      3.8251 |          Bag |          257 |      0.98381 |           24 |
|   33 | Accept |      3.8473 |      3.4564 |      3.7037 |      3.8252 |          Bag |           85 |    0.0010013 |            2 |
|   34 | Accept |      3.8427 |      2.8023 |      3.7037 |      3.8278 |          Bag |           77 |      0.35024 |            6 |
|   35 | Accept |       3.955 |      14.257 |      3.7037 |      3.8282 |          Bag |          357 |    0.0010076 |            1 |
|   36 | Accept |      3.9176 |      5.2097 |      3.7037 |       3.828 |          Bag |          174 |     0.023544 |           11 |
|   37 | Accept |      7.5338 |     0.52654 |      3.7037 |      3.8274 |      LSboost |           42 |     0.001003 |         1812 |
|   38 | Accept |      6.3323 |     0.53495 |      3.7037 |      3.8286 |      LSboost |           42 |      0.95637 |         1818 |
|   39 | Accept |      6.3249 |       1.437 |      3.7037 |      3.8287 |          Bag |          120 |    0.0010064 |         1788 |
|   40 | Accept |      7.4784 |       1.351 |      3.7037 |      3.8291 |      LSboost |           61 |    0.0010037 |           51 |
|===================================================================================================================================|
| Iter | Eval   | Objective   | Objective   | BestSoFar   | BestSoFar   |       Method | NumLearningC-|    LearnRate |  MinLeafSize |
|      | result |             | runtime     | (observed)  | (estim.)    |              | ycles        |              |              |
|===================================================================================================================================|
|   41 | Accept |      6.3214 |     0.58166 |      3.7037 |      3.8291 |          Bag |           42 |      0.13775 |         1811 |
|   42 | Accept |      3.8232 |      1.2417 |      3.7037 |      3.8271 |          Bag |           39 |      0.20316 |           10 |
|   43 | Accept |      4.1452 |      7.8828 |      3.7037 |      3.8259 |          Bag |          416 |    0.0010033 |          168 |
|   44 | Accept |      3.8845 |     0.91192 |      3.7037 |      3.8264 |          Bag |           36 |    0.0010055 |           38 |
|   45 | Accept |      4.3242 |      10.267 |      3.7037 |      3.8215 |      LSboost |          431 |      0.97338 |          185 |
|   46 | Accept |      3.9512 |     0.34449 |      3.7037 |      3.8219 |      LSboost |           12 |      0.24215 |           43 |
|   47 | Accept |       3.859 |      11.126 |      3.7037 |      3.8262 |          Bag |          386 |       0.1618 |           12 |
|   48 | Accept |      6.4537 |     0.85363 |      3.7037 |      3.8219 |      LSboost |           36 |     0.015503 |            1 |
|   49 | Accept |      3.8843 |     0.70305 |      3.7037 |      3.8218 |      LSboost |           26 |      0.26555 |            3 |
|   50 | Accept |       3.922 |      3.7205 |      3.7037 |       3.822 |          Bag |          165 |    0.0027115 |           58 |
```

![/Users/michio/Desktop/PHM/toshare/RULPrediction_images/figure_0.png
](RULPrediction_images//Users/michio/Desktop/PHM/toshare/RULPrediction_images/figure_0.png
)

```text:Output
__________________________________________________________
最適化が完了しました。
MaxObjectiveEvaluations の 50 に達しました。
関数の評価回数の合計: 50
経過時間の合計: 297.6322 秒
目的関数の評価時間の合計: 269.4538

最適な観測実行可能点:
    Method    NumLearningCycles    LearnRate    MinLeafSize
    ______    _________________    _________    ___________

     Bag             21             0.2869          10     

観測された目的関数値 = 3.7037
推定される目的関数値 = 3.822
関数の評価時間 = 0.89814

最適な推定実行可能点 (モデルに基づく):
    Method    NumLearningCycles    LearnRate    MinLeafSize
    ______    _________________    _________    ___________

     Bag             21             0.2869          10     

推定される目的関数値 = 3.822
推定される関数評価時間 = 0.7578
```

最適値において再学習

```matlab:Code
optvars = results.XAtMinEstimatedObjective;
mdl = myBayesOptModel(optvars,subtrainData);
```

# 変数の重要度評価

```matlab:Code
tmp = predictorImportance(mdl);
[~,idx] = sort(tmp,'descend');
mdl.PredictorNames(idx)'
```

```text:Output
ans = 21x1 cell    
'score1'              
'cycle'               
'meanHPT_eff_mod'     
'p1'                  
'meanLPT_eff_mod'     
'meanSmLPC'           
'meanLPT_flow_mod'    
'hs'                  
'DS'                  
'meanHPC_flow_mod'    

```

```matlab:Code
save(fullfile(modeldir,"model.mat"),'mdl');
```

# 学習データに対しての精度検証１

```matlab:Code
load(fullfile(modeldir,"model.mat"),'mdl');
predTrain = mdl.predict(subtrainData);
norm(predTrain-subtrainData.Y)
```

```text:Output
ans = 132.5295
```

```matlab:Code

figure
plot(predTrain,'o');
hold on
plot(trainData.Y,'-')
hold off
```

![/Users/michio/Desktop/PHM/toshare/RULPrediction_images/figure_1.png
](RULPrediction_images//Users/michio/Desktop/PHM/toshare/RULPrediction_images/figure_1.png
)

# 学習データに対しての精度検証２

現時点では各フライトサイクルにおける RUL を予測しているが、ここで RUL は本来であれば傾き -1 で単調減少することを反映させて、傾き -1 の直線に近似する。その時の cycle = 1 (初回フライト時) の Y の値をその unit の RUL とする。

```matlab:Code
% unit 番号が変わるタイミングでデータを分割
diffUnit = diff(trainData.Unit);
idx = find(abs(diffUnit)>0)+1;
idx = [1;idx;height(trainData)];

% それぞれの unit で近似処理
%  y = - x + C;
Clist = 99:-1:40;
error = zeros(size(Clist));
Cfix = zeros(size(idx,1)-1,1);
Ctrue = zeros(size(idx,1)-1,1);
for jj=1:size(idx,1)-1
    tmp = predTrain(idx(jj):idx(jj+1)-1);
    for ii=1:length(Clist)
        C = Clist(ii);
        yy = C - (0:length(tmp));
        error(ii) = norm(yy-tmp);
    end
    [~,minidx] = min(error);
    Cfix(jj) = Clist(minidx);
    Ctrue(jj) = trainData.Y(idx(jj));
end
```

cycle = 1 (初回フライト時) の Y の値をその unit の RUL として誤差評価

```matlab:Code
[Cfix, Ctrue]
```

```text:Output
ans = 49x2    
    76    74
    99    99
    94    94
    88    88
    76    74
    88    88
    81    81
    63    62
    70    70
    75    71

```

```matlab:Code
sqrt(mean((Cfix-Ctrue).^2))
```

```text:Output
ans = 1.7786
```

# テスト用データに対しての予測

```matlab:Code
load(fullfile(modeldir,"model.mat"),'mdl');
predTest = mdl.predict(subtestData);
```

上と同様に直線近似を行い、cycle = 1 (初回フライト時) の Y の値をその unit の RUL とする。

```matlab:Code
% こちらは各 unit で 40 cycle 分なので分けやすい
predTest = reshape(predTest, 40, []);
x1 = 0:39;
%  y = - x + C;
Clist = 99:-1:40;
error = zeros(size(Clist));
Cfix = zeros(size(predTest,2),1);
for jj=1:size(predTest,2)
    for ii=1:length(Clist)
        C = Clist(ii);
        yy = C - x1;
        error(ii) = norm(yy-predTest(:,jj));
    end
    [~,idx] = min(error);
    Cfix(jj) = Clist(idx);
end
```

結果の出力

```matlab:Code
unit = reshape(testData.Unit, 40, []);
filename = reshape(testData.DS, 40, []);

output = table(filename(1,:)',unit(1,:)',Cfix,'VariableNames',["filename","unit","Y"]);
writetable(output, fullfile(subdir, "submission.csv"))
```

提出済の結果との等価性チェック

```matlab:Code
tmp = readtable(fullfile(subdir,"submission_ensemble_alldata_v9.csv"));
sqrt((mean((tmp.Y(1:48)-Cfix).^2)))
```

```text:Output
ans = 0
```

特徴量作成（Model Health Parameters の傾き）を計算（最適化を用いて曲線近似）するために使用する目的関数。

```matlab:Code
function errors = myfun(x,data)

a = x(1);
b = x(2);

yfit = 1-exp((a*data(:,1)).^b);
errors = norm(data(:,2)-yfit);

end

```
