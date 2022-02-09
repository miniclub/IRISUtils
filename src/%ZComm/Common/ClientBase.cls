Include %ZComm.Include

/// RPCクライアント基底クラス
/// RESTを使用
/// %ZUtils.Common.ServerBaseを継承したクラスで規定されたメソッドから
/// サブクラスが生成される
Class %ZComm.Common.ClientBase Extends %RegisteredObject
{

/// デフォルトポート番号
Parameter DefaultHttpPort = 52773;

/// デフォルトリトライ回数
Parameter DefaultRetry = 2;

/// タイムアウト設定
Property Timeout As %Integer [ Calculated ];

/// 接続タイムアウト設定
Property OpenTimeout As %Integer [ Calculated ];

/// リトライ回数
Property MaxRetry As %Integer [ InitialExpression = {..#DefaultRetry} ];

/// HTTPリクエスト
Property conn As %Net.HttpRequest [ Private ];

/// インスタンス作成時の処理
/// インスタンス作成時にHTTP接続の準備を行う
Method %OnNew(host As %String, port As %Integer) As %Status [ Private, ServerOnly = 1 ]
{
	set ret=$$$OK
	try {
		set ..conn = ##class(%Net.HttpRequest).%New()
		set ..conn.Server=host
		set ..conn.Port=$get(port,..#DefaultHttpPort)
	} catch {
		set ret=$$$ERROR(5002,$zerror)
	}
	quit ret
}

/// サーバからのエラーを%Status形式に変換
ClassMethod GetStatus(response As %Net.HttpResponse) As %Status
{
	if response.ContentType["json" {
		set json={}.%FromJSON(response.Data)
		set err=json.errors.%Get(0)
		set it=err.params.%GetIterator()
		while it.%GetNext(.key,.value) {
			set params($I(params))=value
		}
		quit $SYSTEM.Status.Error(err.code,params...)
	}
	quit $$$ERROR(5001,"サーバよりエラーが返されました status="_response.StatusLine)
}

/// タイムアウト設定取得
Method TimeoutGet() As %Integer [ ServerOnly = 1 ]
{
	Quit ..conn.Timeout
}

/// タイムアウト設定保存
Method TimeoutSet(Arg As %Integer) As %Status [ ServerOnly = 1 ]
{
	set ..conn.Timeout=Arg
	Quit $$$OK
}

/// 接続タイムアウト設定取得
Method OpenTimeoutGet() As %Integer [ ServerOnly = 1 ]
{
	Quit ..conn.OpenTimeout
}

/// 接続タイムアウト設定保存
Method OpenTimeoutSet(Arg As %Integer) As %Status [ ServerOnly = 1 ]
{
	set ..conn.OpenTimeout=Arg
	Quit $$$OK
}

}
