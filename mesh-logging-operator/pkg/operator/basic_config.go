package operator

type BasicConfig struct {
	OperatorNamespace     string
	BmcForwarderName      string
	LogstashForwarderName string
	WatchInterval         int
	MinRestartInterval    int
}
