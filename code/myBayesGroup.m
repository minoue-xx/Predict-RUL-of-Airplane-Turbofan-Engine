function error = myBayesGroup(vars,trainData, DSUnitID)
% Copyright 2021 Michio Inoue
% アンサンブル回帰木のベイズ最適化用の目的関数
% 5分割の交差検証

groups = unique(DSUnitID);
hpartition = cvpartition(length(groups),'KFold',5);

errorList = zeros(5,1);
for kk = 1:5
    
    trainingUDunit = groups(hpartition.training(kk));
    trainidx = contains(DSUnitID, trainingUDunit);
    testUDunit = groups(hpartition.test(kk));
    testidx = contains(DSUnitID, testUDunit);
    
    tmpTrain = trainData(trainidx,:);
    tmpTest = trainData(testidx,:);
    
    switch string(vars.Method)
        
        case "Bag"
            t = templateTree(...
                'MinLeafSize',vars.MinLeafSize);
            
            Mdl = fitrensemble(tmpTrain,"Y",'Learners',t,'Method',string(vars.Method),...
                'NumLearningCycles',vars.NumLearningCycles);
            
        case "LSboost"
            t = templateTree(...
                'MinLeafSize',vars.MinLeafSize);
            
            Mdl = fitrensemble(tmpTrain,"Y",'Learners',t,'Method',string(vars.Method),...
                'NumLearningCycles',vars.NumLearningCycles,...
                'LearnRate',vars.LearnRate);
    end
    
    L = loss(Mdl,tmpTest,"Y");
    errorList(kk) = log(1+L);

end
error = mean(errorList);
