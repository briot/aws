from test_support import *

exec_cmd('wsdl2aws', ['-q', '-f', '-doc', 'wsdl_enum.wsdl'])
build_and_run('wsdl_enum')
