#------------------------------------------------------------------------------
# File:         Samsung.pm
#
# Description:  Read Samsung meta information
#
# Revisions:    2009/12/08 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::Samsung;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.00';

%Image::ExifTool::Samsung::SCALADO = (
    GROUPS => { 0 => 'APP4', 1 => 'Samsung', 2 => 'Image' },
    PROCESS_PROC => \&Image::ExifTool::Samsung::ProcessSCALADO,
    TAG_PREFIX => 'Samsung',
    FORMAT => 'int32s',
    SPMO => {
        Name => 'DataLength',
        Unkown => 1,
    },
    WDTH => {
        Name => 'PreviewImageWidth',
        ValueConv => '$val ? abs($val) : undef',
    },
    HGHT => {
        Name => 'PreviewImageHeight',
        ValueConv => '$val ? abs($val) : undef',
    },
    QUAL => {
        Name => 'PreviewQuality',
        ValueConv => '$val ? abs($val) : undef',
    },
);

#------------------------------------------------------------------------------
# Extract information from Samsung JPEG APP4 SCALADO segment
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessSCALADO($$$)
{
    my ($exifTool, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $pos = 0;
    my $end = length $$dataPt;
    SetByteOrder('MM');
    $exifTool->VerboseDir('Samsung APP4 SCALADO', undef, $end);
    for (;;) {
        last if $pos + 12 > $end;
        my $tag = substr($$dataPt, $pos, 4);
        my $unk = Get32u($dataPt, $pos + 4); # (what is this?)
        $exifTool->HandleTag($tagTablePtr, $tag, undef,
            DataPt  => $dataPt,
            Start   => $pos + 8,
            Size    => 4,
            Extra   => ", unk $unk",
        );
        # shorten directory size by length of SPMO
        $end -= Get32u($dataPt, $pos + 8) if $tag eq 'SPMO';
        $pos += 12;
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Samsung - Read Samsung meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to extract meta
information from Samsung images.

=head1 AUTHOR

Copyright 2003-2009, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Samsung SCALADO Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

