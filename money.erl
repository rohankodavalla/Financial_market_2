-module(money).
-import(customer,[createThreads/3]).
-import(banks,[createBanksThreads/2]).

%% ====================================================================
%% API functions
%% ====================================================================
-export([start/1,master/4,display/3,requestToDisplayBalance/4]).

start(Args) ->
    case Args of
        [CustomerFile, BankFile] ->
            {ok, CustomerData} = file:consult(CustomerFile),
            {ok, BankData} = file:consult(BankFile),
            Pid = spawn(money, master, [CustomerData, BankData, #{}, #{}]),
            Pid ! {data, "start"},
            ok;
        _ ->
            io:format("Invalid command-line arguments. Usage: erl -noshell -run money start <customer_file> <bank_file> -s init stop~n")
    end.

display(Max, Min, _) when Min > Max -> ok;
display(Max, Min, Data) when Max >= Min ->
    Row = lists:nth(Min, Data),
    Customer = element(1, Row),
    Amount = element(2, Row),
    io:fwrite("~p: ~p~n", [Customer, Amount]),
    display(Max, Min + 1, Data).

requestToDisplayBalance(Max, Min, BData, BanksMap) when Min > Max -> ok;
requestToDisplayBalance(Max, Min, BData, BanksMap) when Max >= Min ->
    Row = lists:nth(Min, BData),
    Bank = element(1, Row),
    Amount = element(2, Row),
    Pid = maps:get(Bank, BanksMap),
    Pid ! {displayBalance},
    requestToDisplayBalance(Max, Min + 1, BData, BanksMap).

master(CData, BData, CustomerMaps, BanksMap) ->
    receive
        {data, "start"} ->
            io:fwrite("** Customers and loan objectives **~n"),
            display(length(CData), 1, CData),
            io:fwrite("** Banks and financial resources **~n"),
            display(length(BData), 1, BData),
            BankThreads = createBanksThreads(BData, self()),
            CustomerThreads = createThreads(CData, BankThreads, self()),
            master(CData, BData, CustomerThreads, BankThreads);
        {loanRequest, Customer, Amount, BankName} ->
            io:fwrite("~p requests a loan of ~p dollar(s) from ~p~n", [Customer, Amount, BankName]),
            master(CData, BData, CustomerMaps, BanksMap);
        {frombankApproved, BankName, Amount, Customer} ->
            io:fwrite("~p approves a loan of ~p dollars from ~p~n", [BankName, Amount, Customer]),
            master(CData, BData, CustomerMaps, BanksMap);
        {frombankDisApproved, BankName, Amount, Customer} ->
            io:fwrite("~p denies a loan of ~p dollars from ~p~n", [BankName, Amount, Customer]),
            master(CData, BData, CustomerMaps, BanksMap);
        {completed, Customer, Amount} ->
            io:fwrite("~p has reached the objective of ~p dollar(s). Woo Hoo!~n", [Customer, Amount]),
            UpdatedMap = maps:remove(Customer, CustomerMaps),
            Size = maps:size(UpdatedMap),
            if
                Size > 0 ->
                    master(CData, BData, UpdatedMap, BanksMap);
                Size == 0 ->
                    requestToDisplayBalance(length(BData), 1, BData, BanksMap),
                    master(CData, BData, UpdatedMap, BanksMap);
                true ->
                    ok
            end,
            master(CData, BData, CustomerMaps, BanksMap);
        {notcompleted, Customer, LoanAmount} ->
            io:fwrite("~p has not reached the objective of ~p dollar(s). Boo Hoo!~n", [Customer, LoanAmount]),
            UpdatedMap = maps:remove(Customer, CustomerMaps),
            Size = maps:size(UpdatedMap),
            if
                Size > 0 ->
                    master(CData, BData, UpdatedMap, BanksMap);
                Size == 0 ->
                    requestToDisplayBalance(length(BData), 1, BData, BanksMap),
                    master(CData, BData, UpdatedMap, BanksMap);
                true ->
                    ok
            end,
            master(CData, BData, CustomerMaps, BanksMap);
        {myBalance, BankName, BankBalance} ->
            io:fwrite("~p has ~p dollar(s) remaining.~n", [BankName, BankBalance]),
            master(CData, BData, CustomerMaps, BanksMap);
        Other ->
            io:fwrite(" "),
            master(CData, BData, CustomerMaps, BanksMap)
    end.
