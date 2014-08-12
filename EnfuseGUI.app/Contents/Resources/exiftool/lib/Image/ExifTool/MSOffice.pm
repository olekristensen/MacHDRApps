#------------------------------------------------------------------------------
# File:         MSOffice.pm
#
# Description:  Read Microsoft Office ZIP/XML-based files
#
# Revisions:    2009/10/31 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::MSOffice;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::XMP;

$VERSION = '1.00';

# lookup for recognized MSOffice document extensions
my %docType = (
    DOCX => 1,  DOCM => 1,
    DOTX => 1,  DOTM => 1,
    POTX => 1,  POTM => 1,
    PPSX => 1,  PPSM => 1,
    PPTX => 1,  PPTM => 1,  THMX => 1,
    XLAM => 1,
    XLSX => 1,  XLSM => 1,  XLSB => 1,
    XLTX => 1,  XLTM => 1,
);

# generate reverse lookup for file type based on MIME
my %fileType;
{
    my $type;
    foreach $type (keys %docType) {
        $fileType{$Image::ExifTool::mimeType{$type}} = $type;
    }
}

# XML attributes to queue
my %queuedAttrs;
my %queueAttrs = (
    fmtid => 1,
    pid   => 1,
    name  => 1,
);

# keep track of items in a vector (to accumulate as a list)
my $vectorCount;
my @vectorVals;

# MSOffice tags
%Image::ExifTool::MSOffice::Main = (
    GROUPS => { 0 => 'XML', 1 => 'MSOffice', 2 => 'Document' },
    PROCESS_PROC => \&Image::ExifTool::XMP::ProcessXMP,
    VARS => { NO_ID => 1 },
    NOTES => q{
        The table below represents tags which have been observed in Microsoft Office
        ZIP/XML-format documents, but ExifTool will extract any XML meta information
        tags found, even if they don't appear here.
    },
    # These tags all have 1:1 correspondence with FlashPix tags except for:
    #   MSOffice         FlashPix
    #   ---------------  -------------
    #   DocSecurity      Security
    #   Application      Software
    #   LastModifiedBy   LastSavedBy
    #   Description      Comments
    #   Creator          Author
    #   TotalTime (min?) TotalEditTime (sec)
    Application => { },
    AppVersion  => { },
    category    => { },
    Characters  => { },
    CharactersWithSpaces => { },
    CheckedBy   => { },
    Client      => { },
    Company     => { },
    created     => {
        Name => 'CreateDate',
        Groups => { 2 => 'Time' },
        Format => 'date',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    createdType => { Hidden => 1, RawConv => 'undef' }, # ignore this XML type name
    DateCompleted => {
        Groups => { 2 => 'Time' },
        Format => 'date',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    Department  => { },
    Destination => { },
    Disposition => { },
    Division    => { },
    DocSecurity => { },
    DocumentNumber=> { },
    Editor      => { Groups => { 2 => 'Author'} },
    ForwardTo   => { },
    Group       => { },
    HeadingPairs=> { },
    HiddenSlides=> { },
    HyperlinkBase=>{ },
    HyperlinksChanged => { PrintConv => { 'false' => 'No', 'true' => 'Yes' } },
    keywords    => { },
    Language    => { },
    lastModifiedBy => { Groups => { 2 => 'Author'} },
    Lines       => { },
    LinksUpToDate=>{ PrintConv => { 'false' => 'No', 'true' => 'Yes' } },
    Mailstop    => { },
    Manager     => { },
    Matter      => { },
    MMClips     => { },
    modified    => {
        Name => 'ModifyDate', 
        Groups => { 2 => 'Time' },
        Format => 'date',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    modifiedType=> { Hidden => 1, RawConv => 'undef' }, # ignore this XML type name
    Notes       => { },
    Office      => { },
    Owner       => { Groups => { 2 => 'Author'} },
    Pages       => { },
    Paragraphs  => { },
    PresentationFormat => { },
    Project     => { },
    Publisher   => { },
    Purpose     => { },
    ReceivedFrom=> { },
    RecordedBy  => { },
    RecordedDate=> {
        Groups => { 2 => 'Time' },
        Format => 'date',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    Reference   => { },
    revision    => { },
    ScaleCrop   => { PrintConv => { 'false' => 'No', 'true' => 'Yes' } },
    SharedDoc   => { PrintConv => { 'false' => 'No', 'true' => 'Yes' } },
    Slides      => { },
    Source      => { },
    Status      => { },
    TelephoneNumber => { },
    Template    => { },
    TitlesOfParts=>{ },
    TotalTime   => { PrintConv => 'Image::ExifTool::MSOffice::ConvertTotalTime($val)' },
    Typist      => { },
    Words       => { },
);

#------------------------------------------------------------------------------
# Print conversion for TotalTime value
# Inputs: 0) time in minutes (NC)
# Returns: readable time
sub ConvertTotalTime($)
{
    my $val = shift;
    if (Image::ExifTool::IsFloat($val) and $val != 0) {
        if ($val < 1) {
            $val = sprintf("%d seconds", $val * 60); # (I don't think this will happen)
        } elsif ($val < 60) {
            $val = sprintf("%d minutes", $val);
        } elsif ($val < 24 * 60) {
            $val = sprintf("%.1f hours", $val / 60);
        } else {
            $val = sprintf("%.1f days", $val / (24 * 60));
        }
    }
    return $val;
}

#------------------------------------------------------------------------------
# Generate a tag ID for this XML tag
# Inputs: 0) tag property name list ref
# Returns: tagID and outtermost interesting namespace (or '' if no namespace)
sub GetTagID($)
{
    my $props = shift;
    my ($tag, $prop, $namespace);
    foreach $prop (@$props) {
        # split name into namespace and property name
        # (Note: namespace can be '' for property qualifiers)
        my ($ns, $nm) = ($prop =~ /(.*?):(.*)/) ? ($1, $2) : ('', $prop);
        next if $ns eq 'vt';        # ignore 'vt' properties
        if (defined $tag) {
            $tag .= ucfirst($nm);   # add to tag name
        } elsif ($prop ne 'Properties' and $prop ne 'cp:coreProperties' and
                 $prop ne 'property')
        {
            $tag = $nm;
            # save namespace of first property to contribute to tag name
            $namespace = $ns unless $namespace;
        }
    }
    return ($tag, $namespace || '');
}

#------------------------------------------------------------------------------
# We found an XMP property name/value
# Inputs: 0) ExifTool object ref, 1) tag table ref
#         2) reference to array of XMP property names (last is current property)
#         3) property value, 4) attribute hash ref (not used here)
# Returns: 1 if valid tag was found
sub FoundTag($$$$;$)
{
    my ($exifTool, $tagTablePtr, $props, $val, $attrs) = @_;
    return 0 unless @$props;
    my $verbose = $exifTool->Options('Verbose');

    my $tag = $$props[-1];
    $exifTool->VPrint(0, "  - Tag '", join('/',@$props), "'\n") if $verbose > 1;

    # convert to specified character set
    if ($exifTool->{OPTIONS}{Charset} ne 'UTF8' and $val =~ /[\x80-\xff]/) {
        $val = $exifTool->UTF82Charset($val);
    }
    # un-escape XML character entities
    $val = Image::ExifTool::XMP::UnescapeXML($val);

    # queue this attribute for later if necessary
    if ($queueAttrs{$tag}) {
        $queuedAttrs{$tag} = $val;
        return 0;
    }
    my $ns;
    ($tag, $ns) = GetTagID($props);
    if (not $tag) {
        # all properties are in ignored namespaces
        # so 'name' from our queued attributes for the tag
        my $name = $queuedAttrs{name} or return 0;
        $name =~ s/(^| )([a-z])/$1\U$2/g;     # start words with uppercase
        ($tag = $name) =~ tr/-_a-zA-Z0-9//dc;
        return 0 unless length $tag;
        unless ($$tagTablePtr{$tag}) {
            my %tagInfo = (
                Name => $tag,
                Description => $name,
            );
            # format as a date/time value if type is 'vt:filetime'
            if ($$props[-1] eq 'vt:filetime') {
                $tagInfo{Groups} = { 2 => 'Time' },
                $tagInfo{Format} = 'date',
                $tagInfo{PrintConv} = '$self->ConvertDateTime($val)';
            }
            $exifTool->VPrint(0, "  | [adding $tag]\n") if $verbose;
            Image::ExifTool::AddTagToTable($tagTablePtr, $tag, \%tagInfo);
        }
    } elsif ($tag eq 'xmlns') {
        # ignore namespaces (for now)
        return 0;
    } elsif (ref $Image::ExifTool::XMP::Main{$ns} eq 'HASH' and
        $Image::ExifTool::XMP::Main{$ns}{SubDirectory})
    {
        # use standard XMP table if it exists
        my $table = $Image::ExifTool::XMP::Main{$ns}{SubDirectory}{TagTable};
        no strict 'refs';
        if ($table and defined %$table) {
            $tagTablePtr = Image::ExifTool::GetTagTable($table);
        }
    } elsif (@$props > 2 and grep /^vt:vector$/, @$props) {
        # handle vector properties (accumulate as lists)
        if ($$props[-1] eq 'vt:size') {
            $vectorCount = $val;
            undef @vectorVals;
            return 0;
        } elsif ($$props[-1] eq 'vt:baseType') {
            return 0;   # ignore baseType
        } elsif ($vectorCount) {
            --$vectorCount;
            if ($vectorCount) {
                push @vectorVals, $val;
                return 0;
            }
            $val = [ @vectorVals, $val ] if @vectorVals;
            # Note: we will lose any improper-sized vector elements here
        }
    }
    # add any unknown tags to table
    if ($$tagTablePtr{$tag}) {
        my $tagInfo = $$tagTablePtr{$tag};
        if (ref $tagInfo eq 'HASH') {
            # reformat date/time values
            my $fmt = $$tagInfo{Format} || $$tagInfo{Writable} || '';
            $val = Image::ExifTool::XMP::ConvertXMPDate($val) if $fmt eq 'date';
        }
    } else {
        $exifTool->VPrint(0, "  [adding $tag]\n") if $verbose;
        Image::ExifTool::AddTagToTable($tagTablePtr, $tag, { Name => ucfirst $tag });
    }
    # save the tag
    $exifTool->HandleTag($tagTablePtr, $tag, $val);

    # start fresh for next tag
    undef $vectorCount;
    undef %queuedAttrs;

    return 1;
}

#------------------------------------------------------------------------------
# Extract information from an MSOffice ZIP/XML file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid MSOffice file
# Notes: Upon entry to this routine, the file type has already been verified
# and the dirInfo hash contains 2 elements unique to this process proc:
#   MIME    - mime type of main document from "[Content_Types].xml"
#   ZIP     - reference to Archive::Zip object for this file
sub ProcessDOCX($$)
{
    my ($exifTool, $dirInfo) = @_;
    my $zip = $$dirInfo{ZIP};
    my $tagTablePtr = GetTagTable('Image::ExifTool::MSOffice::Main');
    my ($mime, $member);

    # read the content to determine the file type
    my $cType = $zip->memberNamed('[Content_Types].xml');
    if ($cType) {
        my ($buff, $status) = $zip->contents($cType);
        if (not $status and $buff =~ /ContentType\s*=\s*(['"])([^"']+)\.main(\+xml)?\1/) {
            $mime = $2;
        }
    }
    # assume 'DOCX' mime type if would could't determine it otherwise
    $mime or $mime = $Image::ExifTool::mimeType{DOCX};
    # set the file type ('DOCX' by default)
    my $fileType = $fileType{$mime};
    if ($fileType) {
        # THMX is a special case because its contents.main MIME types is PPTX
        if ($fileType eq 'PPTX' and $$exifTool{FILE_EXT} and $$exifTool{FILE_EXT} eq 'THMX') {
            $fileType = 'THMX';
        }
    } else {
        $exifTool->VPrint(0, "Unrecognized MIME type: $mime\n");
        # get MIME type according to file extension
        $fileType = $$exifTool{FILE_EXT};
        $fileType = 'DOCX' unless $fileType and $docType{$fileType};
    }
    $exifTool->SetFileType($fileType);

    # extract meta information from all files in ZIP "docProps" directory
    my $docNum = 0;
    my @members = $zip->members();
    foreach $member (@members) {
        # get filename of this ZIP member
        my $file = $member->fileName();
        next unless defined $file;
        $exifTool->VPrint(0, "File: $file\n");
        # set the document number and extract ZIP tags
        $$exifTool{DOC_NUM} = ++$docNum;
        Image::ExifTool::ZIP::HandleMember($exifTool, $member);
        # process only XML and JPEG files
        next unless $file =~ m{^docProps/.*\.(xml|jpe?g)$}i;
        # get the file contents (CAREFUL! $buff MUST be local since we hand off a value ref)
        my ($buff, $status) = $zip->contents($member);
        $status and $exifTool->Warn("Error extracting $file"), next;
        # extract JPEG as PreviewImage (should only be docProps/thumbnail.jpeg)
        if ($file =~ /\.jpe?g/i) {
            $exifTool->FoundTag('PreviewImage', \$buff);
            next;
        }
        # process XML files (docProps/app.xml, docProps/core.xml, docProps/custom.xml)
        my %dirInfo = (
            DataPt => \$buff,
            DirLen => length $buff,
            DataLen => length $buff,
            XMPParseOpts => {
                FoundProc => \&FoundTag,
            },
        );
        $exifTool->ProcessDirectory(\%dirInfo, $tagTablePtr);
    }
    delete $$exifTool{DOC_NUM};
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::MSOffice - Read Microsoft Office ZIP/XML-based files

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to extract meta
information from Microsoft Office 2007 Word, Excel and PowerPoint files
(essentially ZIP archives of XML files).

=head1 AUTHOR

Copyright 2003-2009, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/MSOffice Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

