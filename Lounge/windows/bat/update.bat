@echo Refreshing: 
@echo   Lounge-windows
@echo off
@cd..
@cd..
@echo Updating smart contract JavaScript library for Ethereum (ethereumjslib)...
@cd smart-contracts
@xcopy ethereumjslib ..\bin-output\Lounge-windows\ethereum\ /E /Y
@cd..
@cd bin-output
@echo Updating core game code (PokerCardGame)...
@xcopy PokerCardGame Lounge-windows\PokerCardGame\ /E /Y
@cd..
@cd Lounge
@cd windows
@echo Done.