#!/usr/bin/env perl
use 5.012;
use FindBin qw($Bin);
use Data::Printer;
use Excel::Writer::XLSX;
use Excel::Writer::XLSX::Utility;
say ">Preparing a simple Excel file testing the module $Bin/excel_demo.xlsx";

# Create new XLSX file
my $workbook = Excel::Writer::XLSX->new("$Bin/excel_demo.xlsx" );
 
# Add new sheets
my $sheet1 = $workbook->add_worksheet('Validate_User_Input');
my $sheet2 = $workbook->add_worksheet('Protected');

# Protect the worksheet operating with the $sheet_object
$sheet2->protect();

#  Add and define a format -> $format
my $format = $workbook->add_format();
   $format->set_bold();
   $format->set_color( 'blue' );
   $format->set_align( 'center' );
 
# METADATA: Add metadata to the file
$workbook->set_custom_property( 'Title',      'LOTUS 2.0 DATASHEET',     'text'   );
$workbook->set_custom_property( 'Checked by',      'LOTUS 2.0',          'text'   );
$workbook->set_custom_property( 'Date completed','2019-12-12T23:00:00Z', 'date'   );

# Excel/Windows readable metadata:
$workbook->set_properties(
    title    => 'LOTUS 2.0',
    author   => 'UserName?',
    comments => 'Created with Perl and Excel::Writer::XLSX!',
    subject  => '16S OTU analisys',
);



#SHEET1
# Write a formatted and unformatted string, row and column notation.
my $col = 0;
my $row = 0;

# WIDTH: set_column( $first_col, $last_col, $width, $format, $hidden, $level, $collapsed )
$sheet1->set_column( 0, 0, 30 );
$sheet1->set_column( 3, 3, 18 );
$sheet1->write( $row, $col, 'OTU_Name', $format );
$sheet1->write( $row+1, $col, 'OTU_1' ); $sheet1->write( $row+1, $col+1, 1.2345 );
$sheet1->write( $row+2, $col, 'OTU_2' ); $sheet1->write( $row+2, $col+1, '=SIN(PI()/4)' );

my $input_format = $workbook->add_format();
$input_format->set_color('red');
$input_format->set_bg_color('yellow');

$sheet1->write( 'D3', 'Type a value 0-10 >>');
$sheet1->write( 'E3', 0, $input_format);
$sheet1->write( 'D2', 'Input validation test');
$sheet1->data_validation('E3',
    {
        validate        => 'integer',
        criteria        => 'between',
        minimum         => 1,
        maximum         => 10,
        input_title     => 'Input an integer:',
        input_message   => 'Between 1 and 100',
        error_message   => 'Sorry, try again (integer between 0 and 10)',
    });
    
# --- CHART
my $worksheet = $workbook->add_worksheet('Chart');
my $bold      = $workbook->add_format( bold => 1 );
 
# Add the worksheet data that the charts will refer to.
my $headings = [ 'Time_Point', 'OTU_1', 'OTU_2' ];
my $data = [
    [ 2,  3,  4,  5,  6,  7 ],
    [ 40, 40, 50, 30, 25, 50 ],
    [ 30, 25, 30, 10, 5,  10 ],
 
];
 
$worksheet->write( 'A1', $headings, $bold );
$worksheet->write( 'A2', $data );
 
# Create a new chart object. In this case an embedded chart.
my $chart1 = $workbook->add_chart( type => 'area', embedded => 1 );
 
# Configure the first series.
$chart1->add_series(
    name       => '=Chart!$B$1',
    categories => '=Chart!$A$2:$A$7',
    values     => '=Chart!$B$2:$B$7',
);
 
# Configure second series. Note alternative use of array ref to define
# ranges: [ $sheetname, $row_start, $row_end, $col_start, $col_end ].
$chart1->add_series(
    name       => '=Chart!$C$1',
    categories => [ 'Chart', 1, 6, 0, 0 ],
    values     => [ 'Chart', 1, 6, 2, 2 ],
);
 
# Add a chart title and some axis labels.
$chart1->set_title ( name => 'Results of sample analysis' );
$chart1->set_x_axis( name => 'Day' );
$chart1->set_y_axis( name => 'Abundance' );
 
# Set an Excel chart style. Blue colors with white outline and shadow.
$chart1->set_style( 11 );
 
# Insert the chart into the worksheet (with an offset).
$worksheet->insert_chart( 'D2', $chart1, 25, 10 );
# --- /CHART
# SHEET2
# Write a formatted and unformatted string, row and column notation.
$sheet2->write( $row, $col, 'Genus', $format );
$sheet2->write( $row+1, $col, 'Escherichia' );
$sheet2->write( 'A3', 'Salmonella' );
$sheet2->write( 'A4', 'Quaquarella' );

# CREATE SHAPE
# Set properties at creation.
my $plus = $workbook->add_shape(
    type   => 'smileyFace',
    id     => 3,
    width  => 111,
    height => 111,
);
$sheet1->insert_shape( 'G3', $plus );

# NOTATION CONVERSION
( $row, $col ) = xl_cell_to_rowcol( 'C2' );    # (1, 2)
my $cellName      = xl_rowcol_to_cell( 1, 2 );    # C2
$workbook->close();
