Class %ZComm.REST Extends %CSP.REST
{

/// 
///   URLMap 
XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/:module/:method" Method="POST" Call="ExecMethod" Cors="true"/>
</Routes>
}

/// メソッドの実行
ClassMethod ExecMethod(module As %String, method As %String) As %Status
{
	set ret=$$$OK
	try {
		set %response.ContentType = "application/json"
		set %response.CharSet="utf-8"
		// インターフェースモジュールチェック
		set class=$get(^%ZModule.Rest(module,method))
		if class="" set ret=$$$ERROR(5001,"メソッド"_method_"がモジュール"_module_"に見つかりません") quit

		set ret=$classmethod(class,"ServerDispatcher",method)
	} catch {
		set ret=$$$ERROR(5002,$zerror)
	}
	quit ret
}

/// ウェブアプリケーションの作成
ClassMethod CreateWebApp() As %Status
{
    set cspProperties("AutheEnabled") = $$$AutheUnauthenticated
    set cspProperties("NameSpace") = "%SYS"
    set cspProperties("Description") = "Remote Procedure Call RESTインターフェース"
    set cspProperties("MatchRoles")=":%All"
    set cspProperties("IsNameSpaceDefault") = $$$NO
    set cspProperties("DispatchClass") = "%ZComm.REST"
    quit ##class(%ZModule.Install).RegistWebApp("/rpc", .cspProperties)
}

}
