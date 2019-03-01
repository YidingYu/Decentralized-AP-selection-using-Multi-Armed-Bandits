%%%%%%%%%%%%%%%%%%%%%%%%% SETTINGS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
rng('default');
seed=12+99;

MaxSim=100; %Number of seeds to use
CCA=-82;    %Clear Channel Assessment
N_APs=32;  %Number of APs
N_STAs=100;   %Number of STAs
L=12000;    %Packet size
CWmin=16;   %Minimum contention window, for every node
ThrReq= 4E06; % Throughput required by STAs (bps)
SLOT=9E-6;  %OFDM time slot
MaxIter=499; %Number of e-greedy iterations
greedy=1;   % 1 for e-greedy, 0 for standard association
eSticky=1;  % 1 for e-sticky, 0 to deactivate (only works if greedy = 1)
epsilon=0.02; % Epsilon value
SC=4;       % Sticky counter
clustered=1; % 1 for clustered STAs, 0 for random uniform placement

%%%%%%%%%%%%%%%%%%%%%%%%% SETTINGS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 


AggrSatisf=zeros(MaxSim*N_STAs,MaxIter+1);  % Holds all satisfaction
AggrAccB=zeros(MaxSim*N_STAs,MaxIter+1);  % Holds all satisfaction
AggrExpl=zeros(MaxSim*N_STAs,MaxIter);  % Holds all satisfaction
AggrNAPs=zeros(MaxSim,N_STAs);

AggrSticky=zeros(MaxSim,N_STAs);    % Holds all sticky counters
AggrEpsilon=zeros(MaxSim*N_STAs,3); % Holds all epsilon usage
AggrBe=zeros(MaxSim,N_STAs*2);  % Holds Bw obtained/ Bw desired
AggrBes=zeros(MaxSim,N_STAs);   % Holds Bw obtained with SSF
AggrBs=zeros(MaxSim,N_STAs);    % Holds Bw obtained with epsilon


simCounter=0;
countS=0;   % Counts the amount of times every possible STA is satisfied
iterFound=zeros(3,MaxSim);  % First row is first iteration convergence was found, second is last
AggrNA_STAS=zeros(MaxSim,1);
for y=1:MaxSim
    
    while(true)
        
        rng(seed+y+simCounter);  %Sets seed for all number generators
        
        [AP,STA,NodeMatrix,shadowingmatrix]=CreateNetwork(N_APs,N_STAs,L,CWmin,SLOT,clustered,ThrReq);
        for i=1:N_STAs
            for j=1:N_APs
                if(NodeMatrix(i+N_APs,j)>=CCA)
                    STA(i).nAPs=STA(i).nAPs+1;  % Number of APs in range
                    STA(i).APs_range(STA(i).nAPs) = j;  % Ids of APs in range
                    STA(i).APs(j)=NodeMatrix(i+N_APs,j);    % RSSI of APs in range
                end
            end
        end
        [AP,STA,Associated]=SSFAssoc(AP,STA,NodeMatrix);
        NA_STAs=0;  % Not Associated STAs due to bad signal
        for i=1:N_STAs
            if(STA(i).associated_AP==0)
                NA_STAs=NA_STAs+1;
            end
        end
        if(NA_STAs>0)
            simCounter=simCounter+1;
        else
            break;
        end
    end
    AggrNA_STAS(y)=NA_STAs;
    Bmax=10E6;
    
    if(greedy==1)
        balance=[0 0 0];
        gen_Be=zeros(N_STAs*2,2); % First value Be, second B
        for j=1:N_STAs
            STA(j).satisf=zeros(1,MaxIter+1);   % Satisfaction
            STA(j).accB=zeros(1,MaxIter+1);   % Satisfaction
            STA(j).expl=zeros(1,MaxIter);   % Exploitation
            STA(j).APSel=zeros(1,MaxIter+1);
            STA(j).APSel(1)=STA(j).associated_AP;
        end
        
        for i=1:MaxIter
            satisfied=0;
            
            [AP,STA]=nodeLoad(AP,STA, Bmax,NodeMatrix,i,SC,CWmin);
            
            if(i==1)    %   SSF values
                for j=1:N_STAs
                    gen_Be(j,1)=STA(j).Be;
                    gen_Be(j,2)=STA(j).B;
                end
            end
            
            for j=1:N_STAs
                if(i>1)
                    if(STA(j).satisf(i)>STA(j).satisf(i-1))
                        satisfied=satisfied+1;
                    end
                else
                    if(STA(j).satisf(i)==1)
                        satisfied=satisfied+1;
                    end
                end
            end
            if(satisfied==(N_STAs-NA_STAs))
                countS=countS+1;
                if(balance(1,1)==0) % Stores first iteration of convergence
                    balance(1,1)=i;
                else
                    balance(1,2)=i; % Stores last iteration of convergence
                end
            end
            if(eSticky == 1)
                
                [STA]=epsilon_greedy_stick(STA,i,epsilon);
            else
                [STA]=epsilon_greedy(STA,i,epsilon);%1/sqrt(i),(1/i)
            end
        end
        %%%% Checks satisfaction after last decision %%%%
        
        [AP,STA]=nodeLoad(AP,STA, Bmax,NodeMatrix,MaxIter+1,SC,CWmin);
        satisfied=0;
        for j=1:N_STAs
            if(STA(j).satisf(MaxIter+1)>STA(j).satisf(MaxIter))
                satisfied=satisfied+1;
            end
        end
        
        if(satisfied==(N_STAs-NA_STAs))
            countS=countS+1;
            if(balance(1,1)==0)
                balance(1,1)=100;
            else
                balance(1,3)=100;
            end
            
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        gen_satisf=zeros(N_STAs,length(STA(1).satisf)); % Stores satisfaction of entire round in a matrix
        gen_accB=zeros(N_STAs,length(STA(1).accB));
        gen_expl=zeros(N_STAs,length(STA(1).accB)-1);
        
        gen_sticky=zeros(N_STAs,1);
        gen_epsilon=zeros(N_STAs,3);
        gen_nAPs=zeros(1,N_STAs);
        for j=1:N_STAs
            gen_satisf(j,:)=STA(j).satisf;
            gen_accB(j,:)=STA(j).accB;
            gen_expl(j,:)=STA(j).expl;
            gen_sticky(j,:)=STA(j).sticky(1);
            gen_Be(j+N_STAs,1)=STA(j).Be;
            gen_Be(j+N_STAs,2)=STA(j).B;
            gen_epsilon(j,:)=STA(j).Epsilon(2,:);
            gen_nAPs(j)=STA(j).nAPs;
        end
        
        
        
        AggrSatisf((1:N_STAs)+(N_STAs*(y-1)),:)=gen_satisf;
        AggrAccB((1:N_STAs)+(N_STAs*(y-1)),:)=gen_accB;
        AggrExpl((1:N_STAs)+(N_STAs*(y-1)),:)=gen_expl;
        AggrSticky(y,:)=gen_sticky;
        AggrEpsilon((1:N_STAs)+(N_STAs*(y-1)),:)=gen_epsilon;
        AggrBe(y,:)=gen_Be(:,1)./gen_Be(:,2);
        AggrBes(y,:)=gen_Be(1:N_STAs,1)'; %% SSF
        AggrBs(y,:)=gen_Be(N_STAs+1:N_STAs*2,1)'; %% e        
        AggrNAPs(y,:)=gen_nAPs;
    end
    
    iterFound(1:3,y)=balance';
    sum(iterFound(1,:)>1);
    
end

