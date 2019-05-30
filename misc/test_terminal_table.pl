use Text::ASCIITable;
$t = Text::ASCIITable->new();
 
$t->setCols('File','Tot','N50');
$t->addRow(1,'Dummy product 1',24.4);
$t->addRow(2,'Dummy product 2',21.2);
$t->addRow(3,'Dummy product 3',12.3);
print $t;
