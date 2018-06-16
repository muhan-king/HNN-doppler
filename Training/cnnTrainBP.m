function cnn=cnnTrainBP(cnn, TrainData, LabelData, to)
% Train CNN using BP gradient descend method
%   TrainData: training data, [x-dim, y-dim, channel-num, batch-size,
%                                batch-count]
%   LabelData: label data, [1, batch-size, batch-count]
%   to: training options

C=[];
[dW, dB]=cnnInitVelocity(cnn);
for e_count=1:to.epochs
    for b_count=1:to.batch
        %% Training Data
        mb_labels=LabelData(:, :, b_count);
        images=TrainData(:, :, :, :, b_count);
        numImages=to.batch_size;
        % Momemtum
        if b_count==to.momIncrease
            to.mom=to.momentum;
        end
           
        %% Feedforward Pass
        [cnn, OutData]=cnnFeedForward(cnn, images);
        
        %% Calculate Cost
        index=sub2ind([cnn.outputDim, to.batch_size], mb_labels, 1:to.batch_size);
        outPut=gpuArray.zeros(cnn.outputDim, to.batch_size);
        outPut(index)=1;
        ceCost=-sum(sum(log(OutData{cnn.LNum}(index))));
        wCost=to.lambda*cnn.wCost/2;
        cost=ceCost/numImages+wCost;
        
        %% BackPropagation
        Delta=cnnBackPropagation(cnn, OutData, outPut);

        %% Gradient Calculation and Update
        W_grad=cell(1, cnn.LNum);
        B_grad=cell(1, cnn.LNum);
        for iLayer=1:cnn.LNum
            switch cnn.Layers{iLayer}.type
                case 3
                    % Fully Connected Layer
                    W_grad{iLayer}=Delta{iLayer+1}*OutData{iLayer-1}';
                    B_grad{iLayer}=sum(Delta{iLayer+1}, 2);
                    dW{iLayer}=to.mom*dW{iLayer}+to.alpha*(W_grad{iLayer}/to.batch_size+to.lambda*dW{iLayer});
                    dB{iLayer}=to.mom*dB{iLayer}+to.alpha*B_grad{iLayer}/to.batch_size;
                    cnn.Layers{iLayer}.W=cnn.Layers{iLayer}.W-dW{iLayer};
                    cnn.Layers{iLayer}.B=cnn.Layers{iLayer}.B-dB{iLayer};
                case 2
                    % Convolutional Layer
                    [W_grad{iLayer}, B_grad{iLayer}]=cnnConvGrad(OutData{iLayer-1}, Delta{iLayer+1});
                    dW{iLayer}=to.mom*dW{iLayer}+to.alpha*(W_grad{iLayer}/to.batch_size+to.lambda*dW{iLayer});
                    dB{iLayer}=to.mom*dB{iLayer}+to.alpha*B_grad{iLayer}/to.batch_size;
                    cnn.Layers{iLayer}.W=cnn.Layers{iLayer}.W-dW{iLayer};
                    cnn.Layers{iLayer}.B=cnn.Layers{iLayer}.B-dB{iLayer};
                case 1
                    % Hybrid Convolutional Layer
                    W_grad{iLayer}.Ka=sum(Delta{iLayer}.Ka(:));
                    W_grad{iLayer}.Kr=sum(Delta{iLayer}.Kr(:));
                    dW{iLayer}.Ka=to.mom*dW{iLayer}.Ka+to.alpha*W_grad{iLayer}.Ka/to.batch_size;
                    dW{iLayer}.Kr=to.mom*dW{iLayer}.Kr+to.alpha*W_grad{iLayer}.Kr/to.batch_size;
                    cnn.Layers{iLayer}.Ka=cnn.Layers{iLayer}.Ka-dW{iLayer}.Ka;
                    cnn.Layers{iLayer}.Kr=cnn.Layers{iLayer}.Kr-dW{iLayer}.Kr;
            end
        end
        
        fprintf('Epoch %d: Cost on iteration %d is %f\n', e_count, b_count, cost);
        C=[C, cost];
    end
    to.alpha=to.alpha/2.0;
    
    [~, preds]=max(OutData{cnn.LNum}, [], 1);
    acc=sum(preds==mb_labels)/numImages;
    fprintf('Accuracy is %f\n', acc);
end
plot(C);