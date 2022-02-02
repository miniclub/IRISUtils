Include %ZComm.Include

/// キュー形式のグローバルをアップロード、ダウンロードする
Class %ZComm.Transfer.REST Extends %CSP.REST
{

/// キューグローバル名(サブクラスで指定)
Parameter GlobalName;

/// モジュール名(サブクラスで指定)
Parameter ModuleName;

///   URLMap 
XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/:namespace/:module" Method="POST" Call="UploadGlobalData" Cors="true"/>
<Route Url="/:namespace/:module" Method="GET" Call="DownloadGlobalData" Cors="true"/>
</Routes>
}

/// キューグローバルのダウンロード
/// パラメータGlobalNameで指定されたグローバルを第１サブスクリプトごとに読み込み、クライアント側に渡す
ClassMethod DownloadGlobalData(namespace As %String, module As %String) As %Status
{
	#dim %request as %CSP.Request
	#dim %response as %CSP.Response
	
	set ret=$$$OK
	try {
		
		// ネームスペース、モジュールのチェック
		if module="" { set ret=$$$ERROR(5001,"モジュール名が設定されていません") quit }
		if namespace="" { set ret=$$$ERROR(5001,"ネームスペースが設定されていません") quit }

		// ^%ZComm.Transferグローバルが存在するかをチェック
		set namespace=$zcvt(namespace,"U")
		if '$data(^%ZComm.Transfer(namespace,module),class) {
			set ret=$$$ERROR(5001,"モジュール"_module_"が存在しません namespace="_namespace)
			quit
		}

		// ネームスペースが存在するかどうかをチェック
		if '##class(%SYS.Namespace).Exists(namespace) {
			set ret=$$$ERROR(5001,"ネームスペース"_namespace_"が存在しません")
			quit
		}

		// ネームスペース変更
		new $namespace
		set $namespace=namespace

		// クラスの存在チェック
		if '##class(%Dictionary.ClassDefinition).ExistsId(class) {
			set ret=$$$ERROR(5001,"クラス"_class_"が存在しません")
			quit
		}

		// Content-Typeの設定
		set %response.ContentType = "application/x-iris-global"

		// グローバルデータ出力
		set ret=$classmethod(class,"Export")

	} catch err {
		set ret=err.AsStatus()
	}
	quit ret
}

/// グローバルのアップロード
ClassMethod UploadGlobalData(namespace As %String, module As %String) As %Status
{
	#dim %request as %CSP.Request
	#dim %response as %CSP.Response

	set ret=$$$OK
	try {
		// ネームスペース、モジュールのチェック
		if module="" { set ret=$$$ERROR(5001,"モジュール名が設定されていません") quit }
		if namespace="" { set ret=$$$ERROR(5001,"ネームスペースが設定されていません") quit }

		// ^%ZComm.Transferグローバルが存在するかをチェック
		set namespace=$zcvt(namespace,"U")
		if '$data(^%ZComm.Transfer(namespace,module),class) {
			set ret=$$$ERROR(5001,"モジュール"_module_"が存在しません namespace="_namespace)
			quit
		}

		// ネームスペースが存在するかどうかをチェック
		if '##class(%SYS.Namespace).Exists(namespace) {
			set ret=$$$ERROR(5001,"ネームスペース"_namespace_"が存在しません")
			quit
		}

		// ネームスペース変更
		new $namespace
		set $namespace=namespace

		// クラスの存在チェック
		if '##class(%Dictionary.ClassDefinition).ExistsId(class) {
			set ret=$$$ERROR(5001,"クラス"_class_"が存在しません")
			quit
		}

		// Content-Typeの設定
		set %response.ContentType = "application/x-iris-global"

		// グローバルの受信
		set ret=..ImportStream(%request.Content)

	} catch err {
		set ret=err.AsStatus()
	}

	quit ret
}

/// 可変長レコードの読込
ClassMethod ReadRecord(ByRef data As %String) As %Status
{

			read glen#2
				set glen=$zwascii(glen)
				if glen>32767 {
					read glen2#2
					set glen=$zwascii(glen2)*32768+(glen#32768)
				}
}

/// グローバルデータのエクスポート
/// グローバルデータを可変長レコード形式で標準出力します
/// 
///   +------+------------------+------+-------------+
///   |len(2)| global reference |len(2)| global data |
///   +------+------------------+------+-------------+
/// 
ClassMethod Export() As %Status
{
	set gbl=..#GlobalName
	set key="" for {
		set key=$order(@gbl@(key))
		quit:key=""

		
	}
	quit $$$OK
}

/// グローバルデータのインポート
/// ストリームにある可変長レコード形式のグローバルデータを読み込む
/// 
ClassMethod ImportStream(stream As %Stream) As %Status
{
	Set sc = $$$OK
	// do something
	Return sc
}

/// モジュール登録
/// ^ZComm.Transferグローバルにモジュール名、グローバル名を設定し
/// Requestがあった際に対応するサブクラスのメソッドを実行する
ClassMethod RegistModule() As %String [ CodeMode = objectgenerator ]
{
	do %code.WriteLine(" quit """_%parameter("ModuleName")_"""")
	set:%parameter("ModuleName")'="" ^%ZComm.Transfer($namespace,%parameter("ModuleName"))=%class.Name
	quit $$$OK
}

/// ウェブアプリケーションの作成
ClassMethod CreateWebApp() As %Status
{
    set cspProperties("AutheEnabled") = $$$AutheUnauthenticated
    set cspProperties("NameSpace") = "%SYS"
    set cspProperties("Description") = "グローバル転送インターフェース"
    set cspProperties("MatchRoles")=":%All"
    set cspProperties("IsNameSpaceDefault") = $$$NO
    set cspProperties("DispatchClass") = "%ZUtils.REST"
    quit ##class(%ZModule.Install).RegistWebApp("/global", .cspProperties)
}

}
