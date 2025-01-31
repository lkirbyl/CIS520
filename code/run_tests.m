%% Example submission: Naive Bayes

%% Load the data
clear all
load ../data/data_with_bigrams.mat;

%%
train1 = train
%%
train = train1
%% Remove Stopwords from train
% Remarks : Makes things worse. What the hell.  
words = stopwords('../data/stop.txt');
%vb = vocab;
%data = train;

train_stripped = rmstopw(train, vocab, words);
%test = rmstopw(test,vocab,words);

%% Make the training data
X = make_sparse(train);
Y = double([train.rating]');
Xt = make_sparse_title(train);
Xb = make_sparse_bigram(train);
%% Make the test data
X_test = make_sparse(test, size(X,2));
Xt_test = make_sparse_title(test, size(Xt,2));
Xb_test = make_sparse_bigram(test, size(Xb,2));
%%
XX = X;
YY = Y;
Xtt = Xt;
Xbb = Xb;
%%
X=XX;
Y=YY;
Xt=Xtt;
Xb=Xbb;
%% Find set of important unigrams and reduce the number of dimensions.

%idx = wordfind1(X,Y,0.001);
%idx2 = wordfind(X,Y,0.00034);
idx3 = wordfind2(X,Y,0.00033);
idxt3 = wordfind2(Xt,Y,0.0006);



%% Determine important bigram. Need to work on it further.
idxb3 = wordfind2(Xb,Y,0.0004);

%in = union(idx,idx2)
%idxbi = wordfind2(X,Y,0.005)

%%
X = X(:,idx3);
Xt = Xt(:,idxt3);
%%
Xb = Xb(:,idxb3);
%%

D = [X(:,idx3) Xt(:,idxt3) Xb(:,idxb3)];

%%
D_test = [X_test(:,idx3) Xt_test(:,idxt3) Xb_test(:,idxb3)];
%% Just a test: Add helpfulness as a feature
helpful_percentages = zeros(size(D,1),1);
for i = 1:size(D,1)
    help = train(i).helpful;
    if ~strcmp(help, '')
        ppl = sscanf(help, '%d of %d');
        helpful_percentages(i) = ppl(1)/ppl(2)*100;
    end
end
%D = [D helpful_percentages];
D = bsxfun(@plus, D, helpful_percentages);

%% Run training
Yk = bsxfun(@eq, Y, [1 2 4 5]);
nb = nb_train_pk([X]'>0, [Yk]);

%% Make the testing data and run testing

Xtest = make_sparse(test, size(X, 2));
Yhat = nb_test_pk(nb, Xtest'>0);


%% Make predictions on test set

% Convert from classes 1...4 back to the actual ratings of 1, 2, 4, 5
%[tmp, Yhat] = max(Yhat, [], 2);
ratings = [1 2 4 5];
%Yhat = ratings(Yhat)';
Yhat = sum(bsxfun(@times, Yhat, ratings), 2);
save('-ascii', 'submit.txt', 'Yhat');

%% Cross validation test/example:
ratings = [1 2 4 5];
tr_hand = @(X,Y) nb_train_pk([X]'>0, [bsxfun(@eq, Y, [1 2 4 5])]);
te_hand = @(c, x) round(sum(bsxfun(@times, nb_test_pk(c, x'>0), ratings), 2));
[rmse, err] = xval_error(train, X, Y, tr_hand, te_hand);

%% Adaboost cross validation:
% now with actually useful cross validation: Trying different values for T
% to find out which one works best. 
addpath(genpath('liblinear'));
possibleTs = 2:15;
rmse = zeros(1,numel(possibleTs));
err = zeros(1,numel(possibleTs));
i = 1;
for T = possibleTs
    tr_hand = @(X,Y) adaboost(X,Y,T);
    te_hand = @(c,x) round(adaboost_test(c,x));
    [rmse(i), err(i)] = xval_error(train, D, Y, tr_hand, te_hand);
    i = i+1;
end
%%
plot(possibleTs, rmse, possibleTs, err)
%% Adaboost xval for singular value
tr_hand = @(X,Y) adaboost(X,Y,5);
te_hand = @(c,x) round(adaboost_test(c,x));
[rmse_s, err_s] = xval_error(train, D, Y, tr_hand, te_hand);

%% Liblinear xval
tr_hand = @(X,Y) liblinear_train(Y,X, '-s 6 -e 1.0');
te_hand = @(c,x) liblinear_predict(ones(size(x,1),1), x, c);
[rmse, err] = xval_error(train, X, Y, tr_hand, te_hand);

%% k-nn xval with random projection to two dimensions
[Z, Zt] = random_projection(D,D_test,10);
Z = full(Z);
Zt = full(Zt);
% Unfortunately my xval-function doesn't work with knn.
part = [train.category];
N = max(part);
e = zeros(1,N);
rm = zeros(1,N);

t = CTimeleft(N);
for i = 1:N
    t.timeleft();
    % Compute training set
    Di = Z(part ~= i, :);
    % Training labels
    Yi = Y(part ~= i);
    % Test fold and expected answers
    TX = Z(part == i, :);
    TY = Y(part == i);
    % Train classifier with training set
    %classifier = train_handle(Di, Yi);
    % Compute error on i'th fold
    Yhat_i = knn(Di, Yi, TX); % trying 1 nearest neighbor
    e(i) = 1/size(TX,1) * (sum(Yhat_i ~= TY));
    rm(i) = sqrt(1/size(TX,1) * sum((TY - Yhat_i).^2));
end
error = 1/double(N)*sum(e);
rmse = 1/double(N)*sum(rm);
