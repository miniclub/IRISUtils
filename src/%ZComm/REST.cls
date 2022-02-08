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
		set ns=$lg(class,1),class=$lg(class,2)
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
    quit ..RegistWebApp("/rpc", .cspProperties)
}

/// Web	アプリケーションの登録
ClassMethod RegistWebApp(name as %String, ByRef spec) as %Status
{
	new $NAMESPACE
	set $namespace="%SYS"
	set st = $$$OK
	if ('##class(Security.Applications).Exists(name)) {
		write !,"Creating Web application"""_name_"""..."
		set st=##class(Security.Applications).Create(name,.spec)
	} else {
		write !,"Updating Web application"""_name_"""..."
		set st=##class(Security.Applications).Modify(name,.spec)
	}
	quit st
}
}