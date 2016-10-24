@echo Deploying to: 
@echo   Lounge-web
@echo   Lounge-android
@echo   Lounge-desktop
@echo   Lounge-windows
@echo off
cd..
cd..
cd bin-output
xcopy PokerCardGame Lounge-web\PokerCardGame /E /Y
xcopy PokerCardGame Lounge-android\PokerCardGame /E /Y
xcopy PokerCardGame Lounge-desktop\PokerCardGame /E /Y
xcopy PokerCardGame Lounge-windows\PokerCardGame /E /Y
@echo Done.