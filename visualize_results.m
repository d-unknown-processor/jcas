function visualize_results
% function to visualize the results generated by run_experiments.m
clear all; clc; close all;
str={'textonboost-ucm','textonboost-quickshift','dsift-ucm','dsift-quickshift'};
vl_xmkdir('results/visualizations');
modes=[0,1,2,6,7];
for i=1:length(str)
    tmp=load(sprintf('results/%s.mat',str{i}),'jcas_objects');
    jcas_objects=tmp.jcas_objects;
    N=length(jcas_objects);
    results=cell(1,N);
    for j=1:N
        fprintf('--------------------------------------------------------\n');
        fprintf('Expt: %s Mode: %d \n',str{i},modes(j));
        obj=jcas_objects{j};
        results{j}=Compute_Statistics_with_Bootstrapping(obj,obj.test.destmatpath);
    end
    results=cat(2,results{:});
    plot(results'); legend('background','car','mean');
    export_fig(sprintf('results/visualizations/%s',str{i}),'-png');
    close;
end
