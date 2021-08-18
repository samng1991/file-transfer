package operator

type BasicConfig struct {
	OperatorNamespace  string
	BmcForwarderName   string
	WatchInterval      int
	MinRestartInterval int
}
