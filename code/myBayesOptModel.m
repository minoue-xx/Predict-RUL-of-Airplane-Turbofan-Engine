function model = myBayesOptModel(vars,trainData2)
% Copyright 2021 Michio Inoue
% ベイズ最適化後のハイパーパラメータを使用してモデル学習（アンサンブル回帰木）

switch string(vars.Method)
    
    case "Bag"
        t = templateTree(...
            'MinLeafSize',vars.MinLeafSize);
        
        model = fitrensemble(trainData2,"Y",'Learners',t,'Method',string(vars.Method),...
            'NumLearningCycles',vars.NumLearningCycles);
        
    case "LSboost"
        t = templateTree(...
            'MinLeafSize',vars.MinLeafSize);
        
        model = fitrensemble(trainData2,"Y",'Learners',t,'Method',string(vars.Method),...
            'NumLearningCycles',vars.NumLearningCycles,...
            'LearnRate',vars.LearnRate);
end


end

