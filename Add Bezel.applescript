-- Add Bezel — 在圖片上按右鍵 → 打開檔案的應用程式 → Add Bezel,自動加上 iPhone 外框
-- 依賴 install.sh 部署到 ~/Library/Application Support/add-bezel/ 的 bezel-frame、bezel.png 與 bezels/
-- 輸出存在原圖旁邊,檔名加上「 Bezel.png」;iPhone Duo 等有多款外框的裝置會跳出對話框選擇

on open theFiles
	set appSupport to (POSIX path of (path to home folder)) & "Library/Application Support/add-bezel/"
	repeat with f in theFiles
		set p to POSIX path of f
		try
			do shell script quoted form of (appSupport & "bezel-frame") & " " & quoted form of p
		on error errMsg
			display alert "加框失敗" message p & linefeed & linefeed & errMsg as critical
		end try
	end repeat
end open

on run
	display dialog "使用方式:在圖片上按右鍵 → 打開檔案的應用程式 → Add Bezel,或把圖片拖到這個 App 圖示上。加框後的圖會存在原圖旁邊。" buttons {"好"} default button 1 with title "Add Bezel"
end run
