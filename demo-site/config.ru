Encoding.default_internal = Encoding.default_external = 'UTF-8' if RUBY_VERSION >= '1.9'
$: << '.'
require './autoforme_demo'
run AutoFormeDemo.app
