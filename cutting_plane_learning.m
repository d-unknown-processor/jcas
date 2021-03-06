function cutting_plane_learning(obj)

if obj.init.given==0
	init=struct();
	init.UP=rand(1,2); %Unary + pairwise
	init.labelcost=rand(1,obj.dbparams.ncat);
	init.alphaMat=rand(obj.topdown.dictionary.params.size_dictionary,obj.dbparams.ncat);
    if(obj.mode>=7)
        init.dict=rand(obj.topdown.features.params.dimension,obj.topdown.dictionary.params.size_dictionary);
    end
else
	init=obj.init.vals;
end

if ~obj.destpathmade
    error('Before doing anything you need to call obj.makedestpath\n')
end


opt_filename=sprintf(obj.optimisation.destmatpath,sprintf('optmodel_%d',obj.mode));
if ~exist(opt_filename,'file')|| obj.force_recompute.optimisation
    fprintf('Computing Cutting plane learning...\n')
    %patterns for calling svm struct
    param=struct();
    param.patterns=obj.dbparams.image_names(obj.dbparams.training);
    
    %Image labels :
    ids=obj.dbparams.training;
    param.labels=cell(1,length(ids));
    
    %Collect the ground truth labelings
    for i=1:length(ids)
        param.labels{i}=get_ground_truth(obj,obj.dbparams.image_names{ids(i)});
    end
    
    %Callbacks :
    param.lossFn = obj.optimisation.lossCB ;
    param.constraintFn  = obj.optimisation.constraintCB ;
    param.featureFn = obj.optimisation.featureCB ;
    param.verbose=1;
    
    switch obj.mode
        case 0
            %unary
            fprintf('No optimisation/learning required for unary only\n');
        case 1
            param.dimension=2;
            %arg
            param.w0=init.UP;
            param.eps=obj.optimisation.params.eps;
            %optsvm=svm_struct_learn(obj.optimisation.params.args,param);
            optsvm=obj.optimisation.svm_struct(param,obj.optimisation.params.max_iter,obj.optimisation.params.C1);
            
            save(opt_filename,'optsvm');
            fprintf('Optimisation computed \n');
        case 2
            %Unary + pairwise + Linear classifier for TD potential \sum
            %alpha_k,l h_k,l + beta_l delta(l present in interest points )
            param.dimension=2+obj.dbparams.ncat*(obj.topdown.dictionary.params.size_dictionary+1);
            param.w0=zeros(1,param.dimension);
            param.w0(1:2)=init.UP;
            if(obj.dbparams.ncat>2)
                [init.alphaMat,init.labelcost,~]=initialize_alpha(obj,param);
            else
                [~,~,init.alphaMat]=initialize_alpha(obj,param);
            end
            param.w0(3:2+obj.dbparams.ncat*obj.topdown.dictionary.params.size_dictionary)=init.alphaMat;
            param.w0(3+obj.dbparams.ncat*obj.topdown.dictionary.params.size_dictionary:end)=init.labelcost;
            param.eps=obj.optimisation.params.eps;
            %optsvm=svm_struct_learn(obj.optimisation.params.args,param);
            optsvm=obj.optimisation.svm_struct(param,obj.optimisation.params.max_iter,obj.optimisation.params.C1);
            
            save(opt_filename,'optsvm');
            fprintf('Optimisation computed \n');
            
        case 3
            %Unary + pairwise + Linear classifier for TD potential \sum
            %alpha_k,l h_k,l + beta_l delta(l present in labeling )
            param.dimension=2+obj.dbparams.ncat*(obj.topdown.dictionary.params.size_dictionary+1);
            param.w0=zeros(1,param.dimension);
            param.w0(1:2)=init.UP;
            param.w0(3:2+obj.dbparams.ncat*obj.topdown.dictionary.params.size_dictionary)=init.alphaMat;
            param.w0(3+obj.dbparams.ncat*obj.topdown.dictionary.params.size_dictionary:end)=init.labelcost;
            param.eps=obj.optimisation.params.eps;
            %optsvm=svm_struct_learn(obj.optimisation.params.args,param);
            optsvm=obj.optimisation.svm_struct(param,obj.optimisation.params.max_iter,obj.optimisation.params.C1);
            
            save(opt_filename,'optsvm');
            fprintf('Optimisation computed \n');
            
        case 4
            %Unary + pairwise + Linear classifier for TD potential \sum
            %alpha_k,l h_k,l + beta_l *||h_l||
            param.dimension=2+obj.dbparams.ncat*(obj.topdown.dictionary.params.size_dictionary+1);
            param.w0=zeros(1,param.dimension);
            param.w0(1:2)=init.UP;
            param.w0(3:2+obj.dbparams.ncat*obj.topdown.dictionary.params.size_dictionary)=init.alphaMat;
            param.w0(3+obj.dbparams.ncat*obj.topdown.dictionary.params.size_dictionary:end)=init.labelcost;
            param.eps=obj.optimisation.params.eps;
            %optsvm=svm_struct_learn(obj.optimisation.params.args,param);
            optsvm=obj.optimisation.svm_struct(param,obj.optimisation.params.max_iter,obj.optimisation.params.C1);
            
            save(opt_filename,'optsvm');
            fprintf('Optimisation computed \n');
        case 5
            %Unary + pairwise  + beta_l delta(l present)
            param.dimension=2+obj.dbparams.ncat;
            param.w0=zeros(1,param.dimension);
            param.w0(1:2)=init.UP;
            param.w0(3:end)=init.labelcost;
            param.eps=obj.optimisation.params.eps;
            %optsvm=svm_struct_learn(obj.optimisation.params.args,param);
            optsvm=obj.optimisation.svm_struct(param,obj.optimisation.params.max_iter,obj.optimisation.params.C1);
            save(opt_filename,'optsvm');
            fprintf('Optimisation computed \n');
            
        case 6
            %Intersection kernel (PAMI)
            %Build the histograms for the training set
            training_histograms_filename=sprintf(obj.topdown.unary.destmatpath,'intersection_kernel_histograms');
            
            if ~exist(training_histograms_filename,'file')|| obj.force_recompute.optimisation
                ctr=1;
                training_histograms=zeros(obj.topdown.dictionary.params.size_dictionary,...
                    obj.dbparams.ncat*length(ids));
                for i=1:length(ids)
                    topdown_unary_filename = sprintf(obj.topdown.unary.destmatpath,sprintf('%s-topdown_unary-%d',obj.dbparams.image_names{ids(i)},obj.topdown.dictionary.params.size_dictionary));
                    tmp=load(topdown_unary_filename); topdown_unary=tmp.topdown_unary;
                    training_histograms(:,ctr:ctr+obj.dbparams.ncat-1)=compute_label_histograms(param.labels{i},topdown_unary,obj.dbparams.ncat);
                    %training_histograms(end-1,ctr:ctr+obj.dbparams.ncat-1)=i*ones(1,obj.dbparams.ncat);
                    %training_histograms(end,ctr:ctr+obj.dbparams.ncat-1)=1:obj.dbparams.ncat;
                    ctr=ctr+obj.dbparams.ncat;
                end
                training_histograms(:,~any(training_histograms(1:end,:),1))=[];
                
                save(training_histograms_filename,'training_histograms');
            else
                tmp=load(training_histograms_filename);
                training_histograms=tmp.training_histograms;
                %param.tHistograms=training_histograms;
            end
            
            param.dimension=2+obj.dbparams.ncat*size(training_histograms,2)+obj.dbparams.ncat;
            param.w0=rand(1,param.dimension);
            param.w0(1:2)=init.UP;
            param.w0(end-obj.dbparams.ncat+1:end)=init.labelcost;
            param.eps=obj.optimisation.params.eps;
            param.tHistograms=training_histograms;
            %optsvm=svm_struct_learn(obj.optimisation.params.args,param);
            optsvm=obj.optimisation.svm_struct(param,obj.optimisation.params.max_iter,obj.optimisation.params.C1);
            save(opt_filename,'optsvm');
            fprintf('Optimisation computed \n');
            
        case 7
            %Latent
            param.dimension=2+obj.dbparams.ncat*(obj.topdown.dictionary.params.size_dictionary+1)+...
            obj.topdown.features.params.dimension*obj.topdown.dictionary.params.size_dictionary;
            param.w0=zeros(1,param.dimension);
            param.w0(1:2)=init.UP;
            param.w0(3:2+obj.dbparams.ncat*(obj.topdown.dictionary.params.size_dictionary))=init.alphaMat;
            param.w0(3+obj.dbparams.ncat*(obj.topdown.dictionary.params.size_dictionary):2+obj.dbparams.ncat*(obj.topdown.dictionary.params.size_dictionary+1))=init.labelcost;
            param.w0(end-obj.topdown.features.params.dimension*obj.topdown.dictionary.params.size_dictionary+1:end)=init.dict;
            param.eps=obj.optimisation.params.eps;
            param.tmp.ncat=obj.dbparams.ncat;
            param.tmp.nwords=obj.topdown.dictionary.params.size_dictionary;
            param.tmp.featdim=obj.topdown.features.params.dimension;
            param.tmp.superpixels.destmatpath=obj.superpixels.destmatpath;
            param.tmp.topdown.features.destmatpath=obj.topdown.features.destmatpath;
            param.nbIterLatent=10;
            param.wordsInd=[];
            %optsvm=svm_struct_learn(obj.optimisation.params.args,param);
            optsvm=obj.optimisation.latent_svm_struct(obj,param,obj.optimisation.params.max_iter,obj.optimisation.params.C1);
            
            save(opt_filename,'optsvm');
            fprintf('Optimisation computed \n');
            
        case 8
            %Latent+structure
            param.dimension=2+obj.dbparams.ncat*(obj.topdown.dictionary.params.size_dictionary+1)+...
            obj.topdown.features.params.dimension*obj.topdown.dictionary.params.size_dictionary+...
            obj.topdown.dictionary.params.size_dictionary*(obj.topdown.dictionary.params.size_dictionary-1)/2;
            param.w0=zeros(1,param.dimension);
            param.w0(1:2)=init.UP;
            param.w0(3:2+obj.dbparams.ncat*(obj.topdown.dictionary.params.size_dictionary))=init.alphaMat;
            param.w0(3+obj.dbparams.ncat*(obj.topdown.dictionary.params.size_dictionary):2+obj.dbparams.ncat*(obj.topdown.dictionary.params.size_dictionary+1))=init.labelcost;
            param.w0(3+obj.dbparams.ncat*(obj.topdown.dictionary.params.size_dictionary+1):2+obj.dbparams.ncat*(obj.topdown.dictionary.params.size_dictionary+1)+...
            obj.topdown.features.params.dimension*obj.topdown.dictionary.params.size_dictionary)=init.dict;
            param.eps=obj.optimisation.params.eps;
            param.nbIterLatent=10;
            %Store ideces for pairwise words
            %Words Pairwise
            param.wordsInd=zeros(obj.topdown.dictionary.params.size_dictionary*(obj.topdown.dictionary.params.size_dictionary-1)/2,1);
            wpit=1;
            for wp=1:obj.topdown.dictionary.params.size_dictionary
                for wp2=wp+1:obj.topdown.dictionary.params.size_dictionary
                    param.wordsInd(wpit)=wp+obj.topdown.dictionary.params.size_dictionary*(wp2-1);
                    wpit=wpit+1;
                end
            end
            %optsvm=svm_struct_learn(obj.optimisation.params.args,param);
            optsvm=obj.optimisation.latent_svm_struct(obj,param,obj.optimisation.params.max_iter,obj.optimisation.params.C1);
            
            save(opt_filename,'optsvm');
            fprintf('Optimisation computed \n');
            
    end
end
end

function [alpha,beta,dict]=initialize_alpha(obj,param)
    if(obj.mode>=2)
        features=cell(1,length(param.patterns));
        for i=1:length(features)
            x=param.patterns{i};
            y=param.labels{i};
            tmp=param.featureFn(param,x,y);
            features{i}=reshape(tmp(3:3+(obj.topdown.dictionary.params.size_dictionary*obj.dbparams.ncat)-1),...
                [obj.topdown.dictionary.params.size_dictionary,obj.dbparams.ncat]);
        end
        features=full(cat(2,features{:}));
        labels=rem(0:size(features,2)-1,obj.dbparams.ncat)+1;
        model=train(labels',sparse(features),'-s 3 -c 10 -B 1','col');
        alpha=model.w(:,1:end-1); beta=model.w(:,end);
        tmp=max(-alpha); tmp(tmp<0)=0;
        alpha=alpha+repmat(tmp,size(alpha,1),1);
        tmp=max([0;-beta]); beta=beta+tmp;
        alpha=alpha'; beta=beta';
        dict=vl_kmeans(features,obj.dbparams.ncat,...
            'algorithm','elkan','initialization','plusplus','numrepetitions',10);
    end

end
