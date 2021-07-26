function model = myBayesOptModel(vars,trainData2)

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


% %  y = - x + C;
% Clist = 100:-1:40;
% error = zeros(size(Clist));
% Cfix = zeros(size(idx,1)-1,1);
% Ctrue = zeros(size(idx,1)-1,1);
% for jj=1:size(idx,1)-1
%     tmp = predTrain(idx(jj):idx(jj+1)-1);
%     for ii=1:length(Clist)
%         C = Clist(ii);
%         yy = C - (0:length(tmp));
%         error(ii) = norm(yy-tmp);
%     end
%     [~,minidx] = min(error);
%     Cfix(jj) = Clist(minidx);
%     Ctrue(jj) = trainData2.Y(idx(jj));
% end
% [Cfix, Ctrue]




end

