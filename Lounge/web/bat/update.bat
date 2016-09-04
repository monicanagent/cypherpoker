@echo Refreshing: 
@echo   Lounge-web
@echo off
@cd..
@cd..
@echo Updating smart contract JavaScript library for Ethereum (ethereumjslib)...
@cd smart-contracts
@xcopy ethereumjslib ..\bin-output\Lounge-web\ethereum\ /E /Y
@cd..
@cd bin-output
@echo Updating core game code (PokerCardGame)...
@xcopy PokerCardGame Lounge-web\PokerCardGame\ /E /Y
@echo Done.