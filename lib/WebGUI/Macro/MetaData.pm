package WebGUI::Macro::MetaData;

#-------------------------------------------------------------------------------
# Author: Arjan Widlak, United Knowledge 2011
#-------------------------------------------------------------------------------
# Licence: GPL http://www.gnu.org/licenses/gpl-2.0.html
#-------------------------------------------------------------------------------
# http://www.unitedknowledge.nl                    serverinfo@unitedknowledge.nl
#-------------------------------------------------------------------------------

use strict;

use WebGUI::Asset;
use WebGUI::Asset::Template;
use WebGUI::Operation::Shared;
use WebGUI::International;
use 5.010;

#---------------------------------------------------
sub process {
    my $session     = shift;
    my $assetId     = shift;
    my $templateId  = shift;


    # Instanciate asset

    my $asset;
    if ($assetId eq 'new') {
        my $className = $session->form->process('class') || 'WebGUI::Asset';
        $asset = WebGUI::Asset->newByPropertyHashRef( $session, { className => $className } );
    }
    else {
        $asset = WebGUI::Asset->newByDynamicClass( $session, $assetId );
        return "Could not instanciate asset with id [$assetId]" unless $asset;
    }

    # Instanciate template
    my $template = WebGUI::Asset::Template->new( $session, $templateId );
    return "Could not instanciate template with id [$templateId]" unless $template;

    # Fetch metaData
    # From WebGUI 7.10.10 the 'getAllMetaDataFields' is available
    # Earlier versions must use getMetaDataFields, which in later versions 
    # takes into account, the allowed classes of a MetaData field. 
    my $metaData = $asset->can('getAllMetaDataFields') 
                 ? $asset->getAllMetaDataFields
                 : $asset->getMetaDataFields;

    # Create loop
    my $var = {};
    my @metaLoop;
    foreach my $id ( keys %{ $metaData } ) {
	my $values;
        my $meta = $metaData->{ $id };
        (my $fieldName = $meta->{ fieldName}) =~ tr/ /_/;

        # Setup options for multiple values
        tie my %options, 'Tie::IxHash';

	foreach my $option ( split /\n/, $meta->{ possibleValues } ) {
		# Key and label are separated by a pipe
		my ($key, $value) = split /\|/, $option;

		# Remove trailing white space
		$key =~ s{ \s+ $ }{}xms;

		$options{ $key } = defined $value ? $value : $key;
	}

        # Append select a value message for selectBoxes
        %options = ("" => WebGUI::International->new($session, 'Asset')->get('Select'), %options) 
            if $meta->{ fieldType } eq 'selectBox';

        # Create form element
        my $form = WebGUI::Form::dynamicField( $session, 
            fieldType       => $meta->{ fieldType } || 'text',
            name            => "metadata_$id",
            value           => $meta->{ value },
            options         => \%options,
            extras          => qq|title="$meta->{description}"|,
        );

        $var->{ $fieldName              } = $meta->{ value };
        $var->{ $fieldName . '_display' } = $options{ $meta->{ value } } || $meta->{ value };
        $var->{ $fieldName . '_form'    } = $form;
        $var->{ $fieldName . '_id'      } = $id;



        push @metaLoop, {
            "name_is_$fieldName"    => 1,
            "id"                    => $id,
            "name"                  => $meta->{ fieldName },
            "value"                 => $meta->{ value },
            "display"               => $options{ $meta->{ value } } || $meta->{ value },
            "form"                  => $form,
            "possible_values_loop"  => [ 
                map {
                    value => $_, 
                    display => $options{ $_ },                    
                    current => ( $_ eq $session->form->process("field_value") ) ?  1 : 0
                    },
                keys %options 
            ],
            "value_loop"            => [ 
                map     { value => $_, display => exists $options{ $_ } ? $options{ $_ } : $_ },
                sort
                split   /\n/, $meta->{ value } 
            ],
        }
    }


    $var->{ meta_loop } = \@metaLoop;

    return $template->process( $var );
}

1;

