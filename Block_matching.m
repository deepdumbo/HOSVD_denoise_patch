function  [pos_arr, X0] = Block_matching(im, par, noiseImage, Class, origin_pos)
searchRadius      = 21;
patchSize         = par.patchSize;
patchSize2        = patchSize^2;
step              = par.step;
%trashHold = 3 * par.sigma^2 * patchSize^2;

N                 = size(im,1)-patchSize+1;
M                 = size(im,2)-patchSize+1;
rows              = [1:step:N];;
rows              = [rows rows(end)+1:N];;
columns           = [1:step:M];
columns           = [columns columns(end)+1:M];
L                 = N*M;
X                 = zeros(patchSize*patchSize, L, 'single');

k    =  0;
for i  = 1:patchSize
    for j  = 1:patchSize
        k    =  k+1;
        blk  =  im(i:end-patchSize+i,j:end-patchSize+j);
        X(k,:) =  blk(:)';
    end
end

%Combine and changed by KazukiAmakawa
X0 = X;
if Class == 0    
    pos_arr = origin_pos;
else
    if par.patch_method == 1
        I     =   (1:L);
        I     =   reshape(I, N, M);
        N1    =   length(rows);
        M1    =   length(columns);
        X         =  X';
        pos_arr   =  zeros(par.patchStackSize, N1*M1 );
        for  i  =  1 : N1
            row     =   rows(i);
            for  j  =  1 : M1
                col     =   columns(j);
                off     =  (col-1)*N + row;
                off1    =  (j-1)*N1 + i;  
                        
                rmin    =   max( row-searchRadius, 1 );
                rmax    =   min( row+searchRadius, N );
                cmin    =   max( col-searchRadius, 1 );
                cmax    =   min( col+searchRadius, M );
                 
                idx     =   I(rmin:rmax, cmin:cmax);
                idx     =   idx(:);
                patchesInSearchArea       =   X(idx, :);        
                currentPatch       =   X(off, :);
                
                dis = 0;
                for k = 1:patchSize2
                    dis   =  dis + (patchesInSearchArea(:,k) - currentPatch(k)).^2;
                end
                dis   =  dis./patchSize2;
                [val,ind]   =  sort(dis);
                %ind(val >= trashHold) = [];
                pos_arr(:,off1)  =  idx( ind(1:par.patchStackSize) );   

            end
        end

    elseif par.patch_method == 2
        %Gaussian Mixture Model Method with BFS nearist researching
        %Added by KazkiAmakawa, source code from 
        gmmtime = clock;
        sprintf('Patch method: GMM cluster with BFS\n');
        [par1, model] = GMMInitial(par.sigma, im);
                            %Import parameter and GMM pre-trained model
        [X1, Sigma_arr] = GMMim2patch(im, noiseImage, par1);
                            %Import data and sigma distance
        GMM_cluster = GMM(Sigma_arr, X1, par1, model, par);
                            %Main Gaussian cluster with model
        sprintf('Gaussian Mixture Model Cluster finished\n');
        fprintf('Total elapsed time = %f min\n', (etime(clock,gmmtime)/60) );


        %BFS for search first par.patchStackSize's values 
        bfstime = clock;

        N1    =   length(rows);
        M1    =   length(columns);
                            %Initial size of research area
        locx      = [-1, -1, -1,  0, 0,  1, 1, 1];
        locy      = [-1,  0,  1, -1, 1, -1, 0, 1];
                            %Initial data for BFS refresh
        Total_Val = 0;
        pos_arr   = zeros(par.patchStackSize, N1 * M1);
                            %Initial values for output and calculate
        
        for j = 1: M1
            for i = 1:N1
                row        = rows(i);
                col        = columns(j);
                Total_Val  = Total_Val + 1;
                Block_id   = (col-1)*N + row; 
                cluster_id = GMM_cluster(Block_id);
                            %Initial data for this search iteration
                
                p = [];
                q = [];
                val = 1;
                p = [p, col];
                q = [q, row];
                stack_var = 1;
                saveimg = zeros(M, N);
                saveimg(col, row) = 1;
                            %Initial cluster set and add initial values
                

                while 1
                    itemx = p(val);
                    itemy = q(val);
                            %Current item location for search


                    if GMM_cluster((itemx-1)*N + itemy) == cluster_id
                        pos_arr(stack_var, Total_Val) = (itemx-1)*N + itemy;
                        stack_var = stack_var + 1;
                            %Find the block are in same cluster or not
                    end

                    if stack_var > par.patchStackSize
                        break;
                            %Stack full break
                    end


                    val = val + 1;
                    
                    for kase = 1:8
                        currentx = itemx + locx(kase);
                        currenty = itemy + locy(kase);
                            %Expand search area
                        if currentx < 1 || currentx > M || currenty < 1 || currenty > N
                            continue;
                            %Out of boundary judge
                        end
                        if saveimg(currentx, currenty) == 0
                            p = [p, currentx];
                            q = [q, currenty];
                            saveimg(currentx, currenty) = 1;
                            %Add new node and sign
                        else
                            continue;
                        end
                    end


                    if val > length(p)
                        break;
                            %Searched all image break condition
                    end
                end 
                
                if stack_var <= par.patchStackSize
                    while 1
                        pos_arr(stack_var, Total_Val) = Block_id;
                        stack_var = stack_var + 1;
                        if stack_var > par.patchStackSize
                            break;
                        end
                    end
                end

            end
        end
        
        fprintf('Total elapsed time = %f min\n', (etime(clock,bfstime)/60) );
        sprintf('Breadth First Search(BFS) to find the first par.patchStackSize list finished\n');

    end
end

