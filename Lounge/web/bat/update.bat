@echo Refreshing: 
@echo   Lounge-web
@echo off
@cd..
@cd..
@echo Updating Ethereum supporting libraries, smart contracts, and utilities...
@xcopy ethereum\ethereumjslib bin-output\Lounge-web\ethereum\ethereumjslib\ /E /Y
@xcopy ethereum\solidity bin-output\Lounge-web\ethereum\solidity\ /E /Y
@cd bin-output
@echo Updating core game code (PokerCardGame)...
@xcopy PokerCardGame Lounge-web\PokerCardGame\ /E /Y
@cd..
@cd Lounge\web
@echo Done.