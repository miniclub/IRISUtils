Include %ZComm.Include

IncludeGenerator %ZComm.Include

/// リモートアクセスのサーバ側の基底クラス
/// このサブクラスに定義されたクラスメソッドからクライアント側の
/// メソッドを生成
Class %ZComm.Common.ServerBase Extends %RegisteredObject [ Abstract ]
{

Parameter InterfaceModule;

ClassMethod ClientGenerator() [ CodeMode = objectgenerator ]
{
	// 抽象クラスの場合、終了
	quit:%class.Abstract $$$OK
	
	// クライアントクラスを求める
	if %class.Name'[".Remote." {
		quit $$$ERROR(5001,"RPCサーバクラスのパッケージ名にはRemoteがないといけません")
	}
	set genclsname=$replace(%class.Name,".Remote.",".Client.")

	// クラスが存在する場合は一旦削除
	if ##class(%Dictionary.ClassDefinition).%ExistsId(genclsname) {
		do ##class(%Dictionary.ClassDefinition).%DeleteId(genclsname)
	}
	// クラスの生成
	set gencls=##class(%Dictionary.ClassDefinition).%New()
	set gencls.Name=genclsname,gencls.Super=$$$ClientBaseClass,gencls.IncludeCode=%class.IncludeCode
	set:%class.IncludeCode'["%ZComm.Include" gencls.IncludeCode=$select(gencls.IncludeCode'="":",",1:"")_"%ZComm.Include"
	set gencls.ProcedureBlock=1
	
	// メソッドの取得
	set mkey="" for {
		set method=%class.Methods.GetNext(.mkey)
		quit:mkey=""
		
		// ClassMethodでない場合、スキップ
		continue:'method.ClassMethod
		
		// メソッドの生成
		set genmtd=##class(%Dictionary.MethodDefinition).%New()
		set genmtd.Name=method.Name,genmtd.FormalSpec=method.FormalSpec,genmtd.ReturnType=method.ReturnType
		set genmtd.ClassMethod=0
		
		do genmtd.Implementation.WriteLine(" for retry=1:1:..MaxRetry { try {")
		// パラメータ設定処理を生成
		kill refargs set refargs=0
		for pnum=1:1:$length(method.FormalSpec,",") {
			set param=$piece(method.FormalSpec,",",pnum)
			continue:param=""
			set ptype=$piece($piece(param,":",2),"="),pname=$piece(param,":"),ref=0
			set:$extract(param)="&" ref=1,pname=$extract(pname,2,99999)
			set:$extract(param)="*" ref=1,pname=$extract(pname,2,*)

			do genmtd.Implementation.WriteLine(" do:$data("_pname_") ..conn.InsertFormData("""_pname_""","_pname_")")
			if ref {
				// 参照渡しのデータを変数に格納
				set refargs($I(refargs))=" set "_pname_"=result.args.%Get("_(refargs-1)_")"
			}
		}
		// POST形式でRESTサーバを呼び出す
		do genmtd.Implementation.WriteLine(" set ret=..conn.Post("""_("/rpc/"_%parameter("InterfaceModule")_"/"_method.Name)_""")")
		do genmtd.Implementation.WriteLine(" quit:$$$ISERR(ret)")
		do genmtd.Implementation.WriteLine(" if ..conn.HttpResponse.StatusCode'=200 set ret=..GetStatus(..conn.HttpResponse) quit")
		do genmtd.Implementation.WriteLine(" set result={}.%FromJSON(..conn.HttpResponse.Data)")
		// 参照渡し
		set refargs="" for {
			set refargs=$order(refargs(refargs),1,line) quit:refargs=""
			do genmtd.Implementation.WriteLine(line)
		}
		do genmtd.Implementation.WriteLine(" } catch { set ret=$$$ERROR(5002,$zerror) }")
		do genmtd.Implementation.WriteLine(" quit:$$$ISOK(ret)||(retry=..MaxRetry)  hang $$$RetryInterval }")
		do genmtd.Implementation.WriteLine(" throw:$$$ISERR(ret) ##class(%Exception.StatusException).CreateFromStatus(ret)")
		do genmtd.Implementation.WriteLine(" quit"_$select(method.ReturnType'="":" result.sc",1:""))

		// クラスに登録
		do gencls.Methods.Insert(genmtd)
		
		// サーバにて呼び出されるようグローバルに登録
		// $namespaceを追加
		set ^%ZModule.Rest(%parameter("InterfaceModule"),method.Name)=$lb($select($extract(%class.Name)="%":"%SYS",1:$namespace),%class.Name)
	}
	set ret=gencls.%Save()
	quit:$$$ISERR(ret) ret
	// コンパイル
	set ret=$SYSTEM.OBJ.Compile(genclsname,"cvk")
	quit ret
}

/// メソッドの入出力を行う
ClassMethod ServerDispatcher(method As %String) As %Status [ CodeMode = objectgenerator ]
{
	// 抽象クラスの場合、終了
	quit:%class.Abstract $$$OK

	// メソッドの取得
	set mkey="" for {
		set mdef=%class.Methods.GetNext(.mkey)
		quit:mkey=""
		
		// ClassMethodでない場合、スキップ
		continue:'mdef.ClassMethod

		do %code.WriteLine(" if method="""_mdef.Name_""" {")		
		// パラメータ設定処理を生成
		set refargs="",args="",preset=""
		for pnum=1:1:$length(mdef.FormalSpec,",") {
			set param=$piece(mdef.FormalSpec,",",pnum)
			continue:param=""
			set ptype=$piece($piece(param,":",2),"="),pname=$piece(param,":"),ref=0
			set:$extract(param)="&" ref=1,pname=$extract(pname,2,*)
			set:$extract(param)="*" ref=1,pname=$extract(pname,2,*)

			set args=$select(args="":"",1:args_",")_$select(ref:"."_pname,1:"%request.Get("""_pname_""")")
			if ref {
				set preset=$select(preset="":"",1:preset_",")_pname_"=%request.Get("""_pname_""")"
				set refargs=$select(refargs="":"",1:refargs_",")_"("_pname_")"
			}
		}
		do:preset'="" %code.WriteLine(" set "_preset)
		do %code.WriteLine($select(mdef.ReturnType="":" do ",1:" set sc=")_".."_mdef.Name_"("_args_")")
		do %code.WriteLine(" write {"_$select(mdef.ReturnType="":"",1:"""sc"":(sc),")_"""args"":["_refargs_"]}.%ToJSON()")
		do %code.WriteLine(" quit $$$OK }")
	}
	quit $$$OK
}

}
