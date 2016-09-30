@echo Refreshing: 
@echo   Lounge-windows
@echo off
@cd..
@cd..
@echo Updating Ethereum supporting libraries, smart contracts, and utilities...
@xcopy ethereum bin-output\Lounge-windows\ethereum\ /E /Y
@cd..
@cd bin-output
@echo Updating core game code (PokerCardGame)...
@xcopy PokerCardGame Lounge-windows\PokerCardGame\ /E /Y
@echo Done.