/*
 * =====================================================================================
 *
 *       Filename:  天气预报.ahk
 *
 *    Description:  可以根据ip自动获取当地的天气信息，天气信息来自http://www.weather.com.cn 
 *					获取ID:http://61.4.185.48:81/g/
 *					快捷键: win+w
 *					可设置显示天数，显示延时，城市ID，是否自动获取ID 
 *                  可以手动更新天气信息
 *					最多可显示6天的天气
 *        Version:  1.3
 *        Created:  2012.5.2 
 *		   Author:	howiefh
 *          Email:  howiefh@gmail.com
 *		     Blog:  http://hi.baidu.com/new/idea_star   http://howiefh.github.io
 *	       Update:  2013.6.6                                                  
 *					更新设置ID模块，可以在gui界面选择城市
 *
 * =====================================================================================
 */

#SingleInstance,Force
#Persistent
#Include include/URLDownloadToVar.ahk
#Include include/json.ahk
#Include include/convertCodepage.ahk
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Init;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
applicationname := SubStr(A_ScriptName, 1, StrLen(A_ScriptName) - 4)

FormatTime, today, , dddd 
weeks := Object(0,"星期日",1,"星期一",2,"星期二",3,"星期三",4,"星期四",5,"星期五",6,"星期六")
for key in weeks
{
	; key 为 today 在 weeks 中的 index
	if (weeks[key] == today)
		break
}

weatherInfoUpdate := 0
initWeatherInfo := 0
GoSub makeWeatherMenu
Gosub weatherINIREAD
return
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Functions;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 判断是否闰年
Syear(year) {
	if( !mod(year, 400) or !mod(year, 4) and mod(year, 100)) 
		return 1
	return 0
}

; 获取下一天的日期
nextDate(ByRef year,ByRef month,ByRef day) {
	days := Object(1,31,2,28,3,31,4,30,5,31,6,30,7,31,8,31,9,30,10,31,11,30,12,31)
	IncMonth := 0
	IncYear := 0 
	MaxMonth := 12
	if( Syear(year) and month == 2 ) 
		MaxDay := 29
	else	
		MaxDay := days[month]
	IncMonth := day // MaxDay
	day := mod((day + 1), MaxDay)
	if(day == 0) 
		day := MaxDay
	IncYear := (month + IncMonth) // MaxMonth
	month := mod((month + IncMonth), 12)
	if(month == 0) 
		month := 12
	year += IncYear
}	
; 根据ip获取id
getCityID()
{
	idResult := URLDownloadToVar("http://61.4.185.48:81/g/")
	if RegExMatch(idResult, "var id=(\d*)", idResult)
	{
		Return idResult1
	}
	return 0
}
; 检测网络连接
InternetCheckConnection(Url="",FIFC=1) { 
	if %A_IsUnicode%
		Return DllCall("Wininet.dll\InternetCheckConnectionW", Str,Url, Int,FIFC, Int,0) 
	else 
		Return DllCall("Wininet.dll\InternetCheckConnectionA", Str,Url, Int,FIFC, Int,0) 
}
; 设置City ID
; WF_data: json内容
; s: 解析的路径,最后一个[]前的部分
; return: 返回城市列表
SelectArea(ByRef WF_data,s){
	WF_CityList := "--"
	loop
	{
		WF_temp := json(WF_data,s . "[" . a_index-1 . "].name")
		
		if (WF_temp == "")
		{ 
			break
		}
		if (a_index == 1)
		{
			WF_CityList := WF_temp
		}
		else {
			WF_CityList := WF_CityList . "|" . WF_temp
		}
	}
	return WF_CityList
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Labels;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 菜单
makeWeatherMenu:
Menu, weatherForecast, Add, 自动获取ID, toggleAutoGetId
Menu, weatherForecast, Add, 设置ID, setCityID 
Menu, weatherForecast, Add, 设置显示延时, setDelay
Menu, weatherForecast, Add, 显示的天数, setShowDayCount 
menu, weatherForecast, add, 更新天气数据, updateWeatherInfo
menu, tray , add , 天气预报,:weatherForecast
return
; 设置城市ID
; setCityID:
; GoSub makeSelectCityIDGUI
   ; InputBox, new_var, 请输入城市ID, , , 240, 100
   ; if NOT ErrorLevel
   ; {
      ; WF_CityID := new_var
	  ; Gosub getWeatherForecast
	  ; if(city == "")
	  ; {
		  ; msgbox, 输入的ID可能有误!
	  ; }
	  ; else
	  ; {
		   ; iniwrite,%WF_CityID%,%a_scriptdir%\%applicationname%.ini,weatherSettings,cityID
	  ; }
   ; }
; return

; 设置显示天气延时
setDelay:
InputBox, new_var, 请输入显示延时, , , 240, 100
   if NOT ErrorLevel
   {
       delay := new_var
	   if ( delay <= 0 or delay > 5000 or delay/500 == 0)
		{
			delay := 2000
			Iniwrite,%delay%,%a_scriptdir%\%applicationname%.ini,weatherSettings, delay
		}
	   iniwrite,%delay%,%a_scriptdir%\%applicationname%.ini,weatherSettings,delay
   }
return
; 设置显示天数
setShowDayCount:
   InputBox, new_var, 请输入要显示的天数（1~6天）, , , 240, 100
   if NOT ErrorLevel
   {
		if(new_var < 1 or new_var >6)
			new_var = 3
      IniWrite, %new_var%, %a_scriptdir%\%applicationname%.ini, weatherSettings, showDayCount
      showDayCount := new_var
	  Gosub getWeatherForecast
   }
return
; 自动获取城市ID开关
toggleAutoGetId:
    if %autoGetCityId%
    {
        autoGetCityId = 0
        Menu, weatherForecast, unCheck, 自动获取ID
		menu, weatherForecast, enable, 设置ID
    }
    else
    {
        autoGetCityId = 1
        Menu, weatherForecast, Check, 自动获取ID
		menu, weatherForecast, disable, 设置ID
		WF_CityID := getCityID()
		iniwrite,%WF_CityID%,%a_scriptdir%\%applicationname%.ini,weatherSettings,cityID
		Gosub getWeatherForecast
    }
	iniwrite,%autoGetCityId%,%a_scriptdir%\%applicationname%.ini,weatherSettings, autoGetCityId
Return
; 更新天气信息 并显示
updateWeatherInfo:
GoSub getWeatherForecast
GoSub showWeatherForecast
Return
; 读配置文件
weatherINIREAD:
IfNotExist,%a_scriptdir%\%applicationname%.ini
{
	autoGetCityId := 1 
	showDayCount := 3
	WF_CityID := getCityID()
	delay := 2000
	Gosub,weatherINIWRITE
	return
}
IniRead,autoGetCityId,%a_scriptdir%\%applicationname%.ini,weatherSettings, autoGetCityId
if(autoGetCityId == 1)
{
	WF_CityID := getCityID()
	iniwrite,%WF_CityID%,%a_scriptdir%\%applicationname%.ini,weatherSettings,cityID
}
else
	IniRead,WF_CityID,%a_scriptdir%\%applicationname%.ini,weatherSettings,cityID
IniRead,showDayCount,%a_scriptdir%\%applicationname%.ini,weatherSettings,showDayCount
if ( showDayCount < 1 or showDayCount > 6)
{
	showDayCount := 3
	Iniwrite,%showDayCount%,%a_scriptdir%\%applicationname%.ini,weatherSettings,showDayCount
}
IniRead,delay,%a_scriptdir%\%applicationname%.ini,weatherSettings,delay
if ( delay <= 0 or delay > 5000 or delay/1000 == 0)
{
	delay := 2000
	Iniwrite,%delay%,%a_scriptdir%\%applicationname%.ini,weatherSettings, delay
}
if %autoGetCityId%
{
	Menu, weatherForecast, Check, 自动获取ID
	menu, weatherForecast, disable, 设置ID
}
Return
; 写配置文件
weatherINIWRITE:
iniwrite,%autoGetCityId%,%a_scriptdir%\%applicationname%.ini,weatherSettings, autoGetCityId
iniwrite,%WF_CityID%,%a_scriptdir%\%applicationname%.ini,weatherSettings,cityID
Iniwrite,%showDayCount%,%a_scriptdir%\%applicationname%.ini,weatherSettings,showDayCount
Iniwrite,%delay%,%a_scriptdir%\%applicationname%.ini,weatherSettings, delay
Return

; 获取天气预报信息
getWeatherForecast:
if(WF_CityID == 0)
{
	WF_CityID := getCityID()
	if(WF_CityID == 0)
		return
	else
		iniwrite,%WF_CityID%,%a_scriptdir%\%applicationname%.ini,weatherSettings,cityID
}
; 获取 json 格式的天气预报
; http://jerryqiu.iteye.com/blog/1106241
; http://www.dream798.com/default.php?page=Display_Info&id=297
; http://service.weather.com.cn/plugin/forcast.shtml?id=pn11#
weatherResult := URLDownloadToVar("http://m.weather.com.cn/data/" . WF_CityID . ".html","UTF-8")
; 失败
if ( weatherResult == 0)
{
	return
}
weatherInfoUpdate = 1

; 转码
; UTF82Ansi 函数见 http://ahk.5d6d.com/thread-1123-1-1.html
if A_IsUnicode != 1
{
	weatherResult := UTF82Ansi(weatherResult)
}
; 用 json 提取数据, 和 javascript 类似
city := json(weatherResult, "weatherinfo.city")
city_en := json(weatherResult, "weatherinfo.city_en")
date_y := json(weatherResult, "weatherinfo.date_y")
week := json(weatherResult, "weatherinfo.week")
Date_year := a_yyyy
; 不能有0
FormatTime, Date_day, DD, d
FormatTime, Date_month, MM, M
; Date_month := a_mm
; Date_day := a_dd
showWeather := ""
loop, %showDayCount%
{
	weather := json(weatherResult, "weatherinfo.weather" . a_index)
	temp := json(weatherResult, "weatherinfo.temp" . a_index)
	showWeather .= Date_month . "." . Date_day . "(" . weeks[mod(key++, 7)] . ")" . ": " . json(weatherResult, "weatherinfo.weather" . a_index) . " " . json(weatherResult, "weatherinfo.temp" . a_index) 
	if ( a_index < showDayCount)
	{
		showWeather .=  "`n"
		nextDate(Date_year, Date_month, Date_day)
	}
}
if (initWeatherInfo == 0 and city <> "")
{
	GoSub showWeatherForecast
	initWeatherInfo = 1
}
Return



#w::
; 输出
showWeatherForecast:
; 还没有获取天气信息
; city 为空说明 getWeatherForecast 未正常执行完，否则显示
if (city == "")
{
	; http://www.autohotkey.com/community/viewtopic.php?t=22293
	; 可以联网
	If InternetCheckConnection("http://www.weather.com.cn") 
	{
		Gosub getWeatherForecast
	}
	else 
	{
		ToolTip, 请检查网络连接是否正确!
		Sleep, 2000
		ToolTip
		Return 
	}
}
else 
{
	ToolTip, % city  "(" city_en ")" "`n"  date_y "	"  week "`n" showWeather
	Sleep, %delay%
	ToolTip
	Return
}
return

; 设置City ID
setCityID:
makeSelectCityIDGUI:
fileread WF_data, cityID.json
WF_CityList := SelectArea(WF_data,"root.area")
Gui, 17: Add, DropDownList, x12 y40 w100 h20 R5 gSelectedArea1 vSelectedAreaVar1 AltSubmit, %WF_CityList%
Gui, 17: Add, DropDownList, x132 y40 w100 h20 R5 gSelectedArea2 vSelectedAreaVar2 AltSubmit, --
Gui, 17: Add, DropDownList, x252 y40 w100 h20 R5 gSelectedArea3 vSelectedAreaVar3 AltSubmit, --
Gui, 17: Add, Button, x372 y40 w90 h30 gWF_OK, 确定
Gui, 17: Add, Text, x12 y80 w340 h30 vWF_selectedCity,
Gui, 17: Show, w475 h128, 选择城市
return

;第一个下拉菜单选择后执行
SelectedArea1:
; gui 不能隐藏
Gui, 17: Submit,NoHide
WF_CityList := SelectArea(WF_data,"root.area[" . SelectedAreaVar1-1 . "].area")
guicontrol, 17:, SelectedAreaVar2,|%WF_CityList%
return
;第二个下拉菜单选择后执行
SelectedArea2:
Gui, 17: Submit,NoHide
WF_CityList := SelectArea(WF_data,"root.area[" . SelectedAreaVar1-1 . "].area[" . SelectedAreaVar2-1 . "].city")
guicontrol, 17:, SelectedAreaVar3,|%WF_CityList%
return
;第三个下拉菜单选择后执行
SelectedArea3:
Gui, 17: Submit,NoHide
return
;点击确定按钮
WF_OK:
; 获取id
WF_CityID := json(WF_data,"root.area[" . SelectedAreaVar1-1 . "].area[" . SelectedAreaVar2-1 . "].city[" . SelectedAreaVar3-1 . "].id")
; 获取城市名
WF_CityName := json(WF_data,"root.area[" . SelectedAreaVar1-1 . "].area[" . SelectedAreaVar2-1 . "].city[" . SelectedAreaVar3-1 . "].name")
guicontrol, 17:, WF_selectedCity, 您选择的城市是: %WF_CityName%  ID是: %WF_CityID%
Gosub getWeatherForecast
iniwrite,%WF_CityID%,%a_scriptdir%\%applicationname%.ini,weatherSettings,cityID
return

17GuiClose:
gui, 17:destroy
return
