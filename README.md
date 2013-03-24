# burst

Ruby parsing reStructuredText.

## Usage

```ruby
require 'burst'

rst    = File.read("file.rst")
parser = Burst::Parser3.new
output = parser.render(rst)
```
