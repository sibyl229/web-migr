package WormBase::Web::Controller::Species;

use strict;
use warnings;
use parent 'WormBase::Web::Controller';


##############################################################
#
#   Species
#   URL space : /species
#
#   /species -> a list of all species
#   /species/CLASS -> an Index page of class
#   /species/CLASS/OBJECT -> a report page
#
#   CUSTOM
#   /species/guide   -> NOTHING
#   /species/guide/SPECIES -> Species info page
#   /species/guide/component
# 
##############################################################


##############################################################
#   
#   /species
# 
#        --> Redirects to the species summary: /species/all
#
##############################################################

sub species_summary :Path('/species') :Args(0)   {
    my ($self,$c) = @_;
    $c->detach('species_index',['all']);
}


##############################################################
#
#   /species/[SPECIES] : The species index page 
#    
#            all     -> all species
#            SPECIES -> an individual species
#
##############################################################

sub species_index :Path('/species') :Args(1)   {
    my ($self,$c,$species) = @_;

    if (defined $c->req->param('inline')) {
	$c->stash->{noboiler} = 1;
    }

    if ($species eq 'all' || $self->_is_species($c,$species)) {
      $c->stash->{section}    = 'species_list';     # Section is where to grab widgets from
      $c->stash->{class}      = 'all';
      $c->stash->{is_class_index} = 1;  
      $c->stash->{species}    = $species;           # Class is the subsection	
      $c->stash->{template}   = 'species/report.tt2';
    } else {
	$c->detach;   # We are neither a supported class or proper species name. Error!	   
    }
}



##############################################################
#
#   Species page components
#   URL space : /species and /species/guide
# 
##############################################################


# SHOULDN'T THESE BE REST TARGETS?
# Component widgets of the guide
# /species/guide/component: two cases
# 1. /species/guide/component/ARG - a widget for the overview page
# 2. /species/guide/component/SPECIES/ARG - a widget for an individual page

# Now rest targets and probably no longer necessary.
#sub species_component_widgets :Path("/species/guide/component") Args {
#    my ($self,$c, @args) = @_;
#    $c->stash->{section} = 'species';
#
#    # These could be species index page widgets
#    if (@args == 1) {
#      my $widget = shift @args;
#      $c->stash->{template} = "species/summary/$widget.tt2";
#
#    # Or per-species widgets
#    } elsif (@args == 2) {
#      my $species = shift @args;
#      my $widget = shift @args;
#      $c->stash->{template} = "species/$species/$widget.tt2";
#      $c->stash->{name}= join(' ',
#			      $c->config->{species_list}->{$species}->{genus},
#			      $c->config->{species_list}->{$species}->{species});
#      
#      # Necessary?
##      unless ($c->stash->{object}) {
##	  my $api = $c->model('WormBaseAPI');  
##	  $c->log->debug("WormBaseAPI model is $api " . ref($api));
##	  $c->stash->{object} =  $api->fetch({class=> ucfirst("species"),
##					      name => $c->stash->{name}}) or die "$!";
##      }
##      my $object= $c->stash->{object};
##      my @fields = $c->_get_widget_fields("species_summary",$widget);
##      foreach my $field (@fields){
##	  $c->stash->{fields}->{$field} = $object->$field; 
##      }      
#    }
#    $c->stash->{noboiler} = 1;
#    $c->forward('WormBase::Web::View::TT');
#}




##############################################################
#
#   /species/[SPECIES]/[CLASS]:
#    
#      Class Summary pages, general and species specific.
#
##############################################################
sub class_index :Path("/species") Args(2) {
    my ($self,$c,$species,$class) = @_;
    if (defined $c->req->param('inline')) {
	$c->stash->{noboiler} = 1;
    }

    # Is this a species known to WormBase?
    if ($species eq 'all' || $self->_is_species($c,$species)) {

#	if ($self->_is_class($c,$class)) {
	    $c->stash->{template}    = 'species/species-class_index.tt2';
	    $c->stash->{section}     = 'species';
	    $c->stash->{class}       = $class;
	   
	    $c->stash->{species}     = $species;  # Provided for formatting, limit searches
	    $c->stash->{is_class_index} = 1;       # used by report_page macro as a flag that this is an index page.
    } else {
	# maybe search class names?
	$c->detach;
    }   
}


##############################################################
#
#   /species/SPECIES/CLASS/OBJECT
#
#            Object Report page via
#                CLASS/OBJECT/FIELD
#                SPECIES/CLASS/OBJECT
#
##############################################################

sub object_report :Path("/species") Args(3) {
    my ($self,$c,$species,$class,$name) = @_;
#    $self->_get_report($self, $c, $class, $name);
    $c->stash->{section}  = 'species';
    $c->stash->{species}  = $species,
    $c->stash->{class}    = $class;
    $c->stash->{is_class_index} = 0;  
    $c->stash->{template} = 'species/report.tt2';
    
    unless ($c->config->{sections}->{species}->{$class}) { 
	# class doesn't exist in this section
	$c->detach;
    }
    
    $c->stash->{species}    = $species;
    $c->stash->{query_name} = $name;
    $c->stash->{class}      = $class;
    $c->log->debug($name);
    
    my $api = $c->model('WormBaseAPI');
    my $object = $api->fetch({class=> ucfirst($class),
			      name => $name}) || $self->error_custom($c, 500, "can't connect to database");
    
    $c->res->redirect($c->uri_for('/search',$class,"$name")."?redirect=1")  if($object == -1 );
    
    if($c->req->param('left') || $c->req->param('right')) {
	$c->log->debug("print the page as pdf");
	$c->stash->{print}={	    left=>[split /-/, $c->req->param('left')],
				    right=>[split /-/, $c->req->param('right')],
				    leftWidth=>$c->req->param('leftwidth'),
	};
    }
    $c->stash->{object} = $object;  # Store the WB object.
   
}



##############################################################
#
#   PRIVATE METHODS
#
##############################################################

# Is the argument a class?
sub _is_class {
    my ($self,$c,$arg) = @_;
    return 1 if (defined $c->config->{'sections'}->{'species'}->{$arg});
    return 0;
}

# Is the argument a species?
sub _is_species {
    my ($self,$c,$arg) = @_;
    return 1 if (defined $c->config->{sections}->{'species_list'}->{$arg});
    return 0;
}




1;
