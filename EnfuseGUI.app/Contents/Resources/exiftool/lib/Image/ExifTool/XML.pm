#------------------------------------------------------------------------------
# File:         XML.pm
#
# Description:  Read a variety of XML-based files
#
# Revisions:    2009/11/01 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::XML;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::XMP;

$VERSION = '1.00';

# XML metadata blocks
%Image::ExifTool::XML::Main = (
    GROUPS => { 0 => 'XML', 1 => 'XML', 2 => 'Image' },
    VARS => { NO_ID => 1 },
);

#------------------------------------------------------------------------------
# We found an XMP property name/value
# Inputs: 0) attribute list ref, 1) attr hash ref,
#         2) property name ref, 3) property value ref
sub HandleCOSAttrs($$$$)
{
    my ($attrList, $attrs, $prop, $valPt) = @_;
    if (not length $$valPt and defined $$attrs{K} and defined $$attrs{V}) {
        $$prop = $$attrs{K};
        $$valPt = $$attrs{V};
        # remove these attributes from the list
        my @attrs = @$attrList;
        @$attrList = ( );
        my $a;
        foreach $a (@attrs) {
            if ($a eq 'K' or $a eq 'V') {
                delete $$attrs{$a};
            } else {
                push @$attrList, $a;
            }
        }
    }
}

#------------------------------------------------------------------------------
# We found a COS property name/value
# Inputs: 0) ExifTool object ref, 1) tag table ref
#         2) reference to array of XMP property names (last is current property)
#         3) property value, 4) attribute hash ref (not used here)
# Returns: 1 if valid tag was found
sub FoundCOS($$$$;$)
{
    my ($exifTool, $tagTablePtr, $props, $val, $attrs) = @_;

    my $tag = $$props[-1];
    unless ($$tagTablePtr{$tag}) {
        $exifTool->VPrint(0, "  [adding $tag]\n");
        Image::ExifTool::AddTagToTable($tagTablePtr, $tag, { Name => ucfirst $tag });
    }
    # convert to specified character set
    if ($exifTool->{OPTIONS}{Charset} ne 'UTF8' and $val =~ /[\x80-\xff]/) {
        $val = $exifTool->UTF82Charset($val);
    }
    # un-escape XML character entities
    $val = Image::ExifTool::XMP::UnescapeXML($val);
    $exifTool->HandleTag($tagTablePtr, $tag, $val);
    return 0;
}

#------------------------------------------------------------------------------
# Extract information from a COS file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid XML file
sub ProcessCOS($$)
{
    my ($exifTool, $dirInfo) = @_;

    # process using XMP module, but override handling of attributes and tags
    $$dirInfo{XMPParseOpts} = {
        AttrProc => \&HandleCOSAttrs,
        FoundProc => \&FoundCOS,
    };
    my $tagTablePtr = GetTagTable('Image::ExifTool::XML::Main');
    my $success = Image::ExifTool::XMP::ProcessXMP($exifTool, $dirInfo, $tagTablePtr);
    delete $$dirInfo{XMLParseArgs};
    return $success;
}

#------------------------------------------------------------------------------
# Extract information from a CaptureOne EIP file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid MSOffice file
# Notes: Upon entry to this routine, the file type has already been verified
# and the dirInfo hash contains 2 elements unique to this process proc:
#   ZIP     - reference to Archive::Zip object for this file
#   Members - ZIP members for all .cos files rooted in the "CaptureOne" directory
sub ProcessEIP($$)
{
    my ($exifTool, $dirInfo) = @_;
    my $zip = $$dirInfo{ZIP};
    my $members = $$dirInfo{Members};

    $exifTool->SetFileType('EIP');

    # extract meta information from all .cos files rooted in ZIP "CaptureOne" directory
    my $member;
    foreach $member (@$members) {
        # get filename of this ZIP member
        my $file = $member->fileName() or next;
        $exifTool->VPrint(0, "File: $file\n");
        # get the file
        my ($buff, $status) = $zip->contents($member);
        $status and $exifTool->Warn("Error extracting $file"), next;
        my %dirInfo = (
            DataPt => \$buff,
            DirLen => length $buff,
            DataLen => length $buff,
        );
        ProcessCOS($exifTool, \%dirInfo);
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::XML - Read a variety of XML-based files

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to extract meta
information various flavours of XML files (currently only .COS supported).
All of the hard work is done by the XMP module.

=head1 AUTHOR

Copyright 2003-2009, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool(3pm)|Image::ExifTool>,
L<Image::ExifTool::XMP(3pm)|Image::ExifTool::XMP>

=cut

