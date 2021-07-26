function error = myBayesGroup(vars,trainData, trainData2)


DSunit = trainData.DS + trainData.Unit;
groups = unique(DSunit);
hpartition = cvpartition(length(groups),'KFold',5);

% diffUnit = diff(trainData.Unit);
% idx = find(abs(diffUnit)>0)+1;
% idx = [[1;idx],[idx-1;height(trainData)]];
% n = length(idx)-1;
% hpartition = cvpartition(n,'KFold',5);


errorList = zeros(5,1);
for kk = 1:5
    
    trainingUDunit = groups(hpartition.training(kk));
    trainidx = contains(DSunit, trainingUDunit);
    testUDunit = groups(hpartition.test(kk));
    testidx = contains(DSunit, testUDunit);
    
    tmpTrain = trainData2(trainidx,:);
    tmpTest = trainData2(testidx,:);
    
    % vars = [Method,NumLearningCycles,LearnRate,MinLeafSize,MinNumSplits,NumVariablesToSample];
    
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
%     predTest = predict(Mdl,tmpTest);
%     errorList(kk) = sqrt(mean((predTest-tmpTest.Y).^2));


end
error = mean(errorList);
