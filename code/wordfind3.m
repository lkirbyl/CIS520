function [idx] = wordfind3(X,Y,df_seed)


%%
%df_seed = 0.0005
idx = zeros(1,size(X,2));
thresh = int32(df_seed * size(X,1))
id = zeros(5,size(X,2));
t = CTimeleft(4);

    for i=[1 2 4 5]
        
        rows = find(Y==i);
        for j = 1:size(X,2)
            A = X(rows,j);
            num = sum(A>0);
            if num(1,1) >= thresh
                id(i,j) = 1   ; 
            end   
        end
    t.timeleft();    
    end
    
    
    idx = find(sum(id)>=1);
end