%% @author admin
%% @doc @todo Add description to banks.


-module(banks).

%% ====================================================================
%% API functions
%% ====================================================================
-export([createBanksThreads/2,toCreateThreads/5,loanReq/3]).



%% ====================================================================
%% Internal functions
%% ====================================================================

toCreateThreads(Max,Min,_,TempMap,_) when Min > Max -> TempMap;
toCreateThreads(Max,Min,Data,TempMap,MasterPid) when Min =< Max ->
	Row = lists:nth(Min,Data),
	BankName = element(1,Row),
	BankBalance = element(2,Row),
	Pid = spawn(banks,loanReq,[BankName,BankBalance,MasterPid]),
%% 	io:fwrite("Thread create ~p : ~p~n",[Pid,BankName]),
    UpdatedMap = maps:put(BankName,Pid,TempMap),
	toCreateThreads(Max,Min+1,Data,UpdatedMap,MasterPid).


loanReq(BankName,BankBalance, MasterPid) ->
	receive
		{request,Customer,Amount,CustomerPid} ->
			
		if 
	      BankBalance - Amount >= 0 -> 
			  NewBal = BankBalance - Amount,
%% 			  io:fwrite("Loan Request from ~p of ~p (dollars) is approved by ~p: Balance : ~p~n",[Customer,Amount,BankName,NewBal]),
			  CustomerPid ! {reply,BankName,Amount,"Approved"},
			  MasterPid ! {frombankApproved, BankName, Amount,Customer};
	      true ->
			  NewBal = BankBalance,
%% 	     io:fwrite("Loan Request from ~p of ~p (dollars) is not approved by ~p: Balance : ~p~n",[Customer,Amount,BankName,NewBal]),
		      CustomerPid ! {reply,BankName,Amount,"Not Approved"},
			  MasterPid ! {frombankDisApproved, BankName, Amount,Customer}
		end,
	    loanReq(BankName,NewBal, MasterPid);
		
		{displayBalance} ->
			MasterPid ! {myBalance,BankName,BankBalance}
	end.


createBanksThreads(BData, MasterPid)->
	BankThreads = toCreateThreads(length(BData),1,BData,#{},MasterPid).
