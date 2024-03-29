package WormBase::API::Role::Object;

use Moose::Role;
use File::Path 'mkpath';
use WormBase::API::ModelMap;
use Moose::Util::TypeConstraints;

# I should have an abstract method for id():
# provided with a class and a name, return the internal ID, if different.

# TODO:
# Synonym (other_name?)
# DONE (mostly): Database and DB_Info parsing
# Titles / description / definition
# Phenotypes observed/not_observed
# Where do hashtables (used for decisions) go? See _common_name()

#######################################################
#
# Attributes. Some of these aren't really Object Roles.
#
#######################################################

# NECESSARY?
#has 'MAX_DISPLAY_NUM' => (
#    is      => 'ro',
#    default => 10,
#);

class_type 'Ace::Object';

has 'object' => (
    is  => 'rw',
    isa => 'Maybe[Ace::Object]',
    default => undef,
);


has 'dsn' => (
    is       => 'ro',
    isa      => 'HashRef',
    required => 1,
);

has 'log' => (
    is => 'ro',
);

has 'tmp_base' => (
    is => 'ro',
);


has 'pre_compile' => (
    is => 'ro',
);

has 'search' => (
    is => 'ro',
);

has 'datomic' => (
    is => 'ro',
);

# Set up our temporary directory (typically outside of our application)
sub tmp_dir {
    my $self = shift;
    my @sub_dirs = @_;
    my $path = File::Spec->catfile($self->tmp_base, @sub_dirs);

    mkpath($path, 0, 0777) unless -d $path;
    return $path;
}



#######################################################
#
# Generic methods, shared across Ace classes.
#
#######################################################

################
#  Names
################

=head3 name

This method will return a data structure of the
name and ID of the requested object.

=over

=item PERL API

 $data = $model->name();

=item REST API

B<Request Method>

GET

B<Requires Authentication>

No

B<Parameters>

A class and object ID.

B<Returns>

=over 4

=item *

200 OK and JSON, HTML, or XML

=item *

404 Not Found

=back

B<Request example>

curl -H content-type:application/json http://api.wormbase.org/rest/field/[CLASS]/[OBJECT]/name

B<Response example>

<div class="response-example"></div>

=back

=cut

# Template: [% name %]

has 'name' => (
    is       => 'ro',
    required => 1,
    lazy     => 1,
    builder  => '_build_name',
);

sub _build_name {
    my ($self) = @_;
    my $object = $self->object;
    return {
        description => "The name and WormBase internal ID of $object",
        data        =>  $self->_pack_obj($object),
    };
}

has 'host' => (
    is          => 'ro',
    required    => 1,
    lazy        => 1,
    default => sub {
        my ($self) = @_;
        return `hostname`;
    },
);

has '_common_name' => (
    is       => 'ro',
    required => 1,
    lazy     => 1,
    builder  => '_build__common_name',
);

sub _build__common_name {
    my ($self) = @_;
    return $self->_make_common_name($self->object);
}

sub _make_common_name {
    my ($self, $object) = @_;
    my $class  = $object->class;

	my $name;

    my $WB2ACE_MAP = WormBase::API::ModelMap->WB2ACE_MAP;
    if (my $tag = $WB2ACE_MAP->{common_name}->{$class}) {
        $tag = [$tag] unless ref $tag;
        my $dbh = $self->ace_dsn->dbh;

        foreach my $tag (@$tag) {
            last if $name = $dbh->raw_fetch($object, $tag);
        }
    }

    if (!$name and
        my $wbclass = WormBase::API::ModelMap->ACE2WB_MAP->{fullclass}->{$class}) {
        if ($wbclass->meta->get_method('_build__common_name')->original_package_name ne __PACKAGE__) {
            # this has potential for circular dependency...
#             $self->log->debug("$class has overridden _build_common_name");
            $name = $self->_api->wrap($object)->_common_name if $self->can('_api');
        }
    }
    $name //= eval { $self->ace_dsn->dbh->raw_fetch($object, "Public_name"); };
	$name //= $object->name;
    $name =~ s/\\(.)/$1/g;
    return $name; # caution: $name should be a string!
}

=head3 other_names

This method will return a data structure containing
other names that have been used to refer to the object.

=over

=item PERL API

 $data = $model->other_names();

=item REST API

B<Request Method>

GET

B<Requires Authentication>

No

B<Parameters>

a class and an object ID.

B<Returns>

=over 4

=item *

200 OK and JSON, HTML, or XML

=item *

404 Not Found

=back

B<Request example>

curl -H content-type:application/json http://api.wormbase.org/rest/field/[CLASS]/[OBJECT]/other_names

B<Response example>

<div class="response-example"></div>

=back

=cut

# Template: [% other_names %]

has 'other_names' => (
    is       => 'ro',
    required => 1,
    lazy     => 1,
    builder  => '_build_other_names',
);

sub _build_other_names {
    my ($self) = @_;
    my $object = $self->object;

    # We will just stringify other names; no sense in linking them.
    my @names = map { "$_" } $object->Other_name;
    return {
        description => "other names that have been used to refer to $object",
        data        => @names ? \@names : undef
    };
}

=head3 best_blastp_matches

This method returns a data structure containing
the best BLASTP matches for the current gene or protein.

=over

=item PERL API

 $data = $model->best_blastp_matches();

=item REST API

B<Request Method>

GET

B<Requires Authentication>

No

B<Parameters>

A class of gene or protein and a gene
or protein ID.

B<Returns>

=over 4

=item *

200 OK and JSON, HTML, or XML

=item *

404 Not Found

=back

B<Request example>

curl -H content-type:application/json http://api.wormbase.org/rest/field/[GENE|PROTEIN]/[OBJECT]/best_blastp_matches

=head5 Response example

=cut

# Template: [% best_blastp_matches %]

# This is A Bad Idea. if _all_proteins is ever changed in Gene,
# nobody will notice there's a problem until a Gene page is open
# with homology widget open. Solution: make a new role. -AD
has 'best_blastp_matches' => (
    is       => 'ro',
    required => 1,
    lazy     => 1,
    builder  => '_build_best_blastp_matches',
);

# Fetch all of the best_blastp_matches for a list of proteins.
# Used for genes and proteins
sub _build_best_blastp_matches {
    my ($self) = @_;
    my $object = $self->object;
    my $class  = $object->class;

    my $proteins;
    # Only for genes or proteins.
    if ($class eq 'Gene') {
        $proteins = $self->_all_proteins;
    } elsif ($class eq 'Protein') {
        # current_object might already be a protein.
        $proteins = [$self->object] unless $proteins;
    }

    if (@$proteins == 0) {
      return {  description => 'no proteins found, no best blastp hits to display',
                data        => undef,
      };
    }

    my ($biggest) = sort {$b->Peptide(2)<=>$a->Peptide(2)} @$proteins;

    my @pep_homol = $biggest->Pep_homol;
    my $length    = $biggest->Peptide(2);

    my @hits;

    # find the best pep_homol in each category
    my %best;
    return {  description => 'no proteins found, no best blastp hits to display',
              data        => undef,
    } unless @pep_homol;
    for my $hit (@pep_homol) {
        # Ignore mass spec hits
        #     next if ($hit =~ /^MSP/);
        next if $hit eq $biggest;    # Ignore self hits
        my ($method, $score) = $hit->row(1) or next;

        my $prev_score = (!$best{$method}) ? $score : $best{$method}{score};
        $prev_score = ($prev_score =~ /\d+\.\d+/) ? $prev_score . '0'
                                                  : "$prev_score.0000";
        my $curr_score = ($score =~ /\d+\.\d+/) ? $score . '0'
                                                : "$score.0000";

        $best{$method} =
          {score => $score, hit => $hit, adjusted_score => $curr_score}
          if !$best{$method} || $prev_score < $curr_score;
    }

    foreach (values %best) {
        my $covered = $self->_covered($_->{score}->col);
        $_->{covered} = $covered;
    }

    # I think the perl glitch on x86_64 actually resides *here*
    # in sorting hash values.  But I can't replicate this outside of a
    # mod_perl environment
    # Adding the +0 forces numeric context
    my $id = 0;
    foreach (sort {$best{$b}{adjusted_score} + 0 <=> $best{$a}{adjusted_score} + 0} keys %best)
    {
        my $method = $_;
        my $hit    = $best{$_}{hit};

        # Try fetching the species first with the identification
        # then method then the embedded species
        my $species = $best{$method}{hit}->Species || $self->id2species($hit) || $self->id2species($method);

        # Not all proteins are populated with the species
        $species =~ s/^(\w)\w* /$1. / if $species;
        my $description = $best{$method}{hit}->Description
          || $best{$method}{hit}->Gene_name;
        my ($class, $id);

       # this doesn't seem optimal... maybe there should be something in config?
        if($hit =~ /(\w+):(.+)/ && $hit->Database && !($method =~ /worm|briggsae|remanei|japonica|brenneri|pristionchus/)) { #try to link out to database
            my $accession = $2;
            my @databases = $hit->Database;
            foreach my $db (@databases) {
              foreach my $dbt ($db->col){
                 map {if($_ =~ "$accession"){$class = $db; $id = $accession}} $dbt->col;
              }
            }

        } else {
            $description ||= eval {
                $best{$method}{hit}->Corresponding_CDS->Brief_identification;
            };

            # Kludge: display a description using the CDS
            if (!$description) {
                for my $cds (eval {$best{$method}{hit}->Corresponding_CDS}) {
                    next if $cds->Method eq 'history';
                    $description ||= "gene $cds";
                }
            }
            $class = 'protein';
        }
        next if ($hit =~ /^MSP/);
        $species =~ /(.*)\.(.*)/;
        my $taxonomy = {genus => $1, species => $2};

        push @hits, {
            taxonomy => $taxonomy,
            # custom packing for linking out to external sources
            hit      => {   class => $class ? "$class" : $hit->class,
                            id => $id || "$hit",
                            label => "$hit"},
            description => $description && "$description",
            evalue      => sprintf("%7.3g", 10**-$best{$_}{score}),
            percent     => $length == 0 ? '0' : sprintf("%2.1f%%", 100 * ($best{$_}{covered}) / $length),
        };
    }

    return {
        description => 'best BLASTP hits from selected species',
        data        => {biggest=>"$biggest", hits => @hits ? \@hits : undef}
    };
}



=head3 central_dogma

This method will return a data structure containing
the central dogma from the perspective of the supplied
(gene|transcript|cds|protein)

=over

=item PERL API

  $data = $model->central_dogma();

=item REST API

B<Request Method>

GET

B<Requires Authentication>

No

B<Parameters>

A class and object ID.

B<Returns>

=over 4

=item *

200 OK and JSON, HTML, or XML

=item *

404 Not Found

=back

B<Request example>

curl -H content-type:application/json http://api.wormbase.org/rest/field/[CLASS]/[OBJECT]/central_dogma

B<Response example>

<div class="response-example"></div>

=back

=cut

# Template: [% central_dogma %]

has 'central_dogma' => (
    is         => 'ro',
    lazy_build => 1,
);


sub _build_central_dogma {
    my $self   = shift;
    my $object = $self->object;
    my $class  = $object->class;

    # Need to get the root element, a gene.
    my $gene;
    if ($class eq 'Gene') {
	$gene = $object;
    } elsif ($class eq 'CDS') {
	$gene = $object->Gene;
    } elsif ($class eq 'Protein') {
	my %seen;
	my @cds = grep { $_->Method ne 'history' } $object->Corresponding_CDS;
	$gene = $cds[0]->Gene if $cds[0];
    } else {
    }
    unless ($gene) {
    return { description => 'the central dogma from the perspective of this protein',
         data        => undef };
    }

    my $gff = $self->gff_dsn || return { description => 'the central dogma from the perspective of this protein',
         data        => undef };

    my %data;
    $data{gene} = $self->_pack_obj($gene);

    foreach my $cds ($gene->Corresponding_CDS) {
	my $protein = $cds->Corresponding_protein;

	my $transcript = $cds->Corresponding_transcript;

	# Fetch the intron/exon sequences from GFF
#	my ($seq_obj) = sort {$b->length<=>$a->length}
#	grep {$_->method eq 'Transcript'} $gff->fetch_group(Transcript => $transcript);

    # eval {$gff->get_features_by_name()}; return if $@;
	my ($seq_obj) = $gff->get_features_by_name(Transcript => $transcript);

#	$self->log->debug("seq obj: " . $seq_obj);
	$seq_obj->ref($seq_obj); # local coordinates
	# Is the genefinder specific formatting cruft?
	my %seenit;
	my @features =
	    sort {$a->start <=> $b->start}
	grep { $_->info eq $cds && !$seenit{$_->start}++ }
	$seq_obj->features(qw/five_prime_UTR:Coding_transcript exon:Pseudogene coding_exon:Coding_transcript three_prime_UTR:Coding_transcript/);
	my @exons;
	foreach (@features) {
	    push @exons, { start => $_->start,
			   stop  => $_->stop,
			   seq   => $_->dna };
	}

	push @{$data{gene_models}},{ cds     => $self->_pack_obj($cds),
				     exons   => \@exons,
				     protein => $self->_pack_obj($protein)
	};
    }

    return { description => 'the central dogma from the perspective of this protein',
	     data        => \%data };
}




# the following is a candidate for retrofitting with ModelMap
sub _build_central_dogma2 {
    my ($self) = @_;
    my $object = $self->object;
    my $class  = $object->class;
    my $data;

    my $gene;
    # Need to get the root element, a gene.
    if ($class eq 'Gene') {
	$gene = $object;
    } elsif ($class eq 'CDS') {
	$gene = $object->Gene;
    } elsif ($class eq 'Protein') {
	my %seen;
	my @genes = grep { ! $seen{%_}++ } map { $_->Gene } grep{ $_->Method ne 'history'}  $object->Corresponding_CDS;
	$gene = $genes[0];
    }

    # Transcripts
    my @transcripts = $gene->Corresponding_transcript;

    # Each transcript has one or more CDS
    foreach my $transcript (@transcripts) {
	my @cds = $transcript->Corresponding_CDS;

	foreach my $cds (@cds) {
	    my @proteins = map { $self->_pack_obj($_) } $cds->Corresponding_protein;
	    push @{$data->{transcripts}},{ transcript => $self->_pack_obj($transcript),
					   cds        => $self->_pack_obj($cds),
					   proteins   => \@proteins,
	    };
	}
    }

    $data->{gene} = $self->_pack_obj($gene);

    return {
        description => "the central dogma of the current object",
        data        => $data,
    };
}


=head3 description

This method will return a data structure containing
a brief description of the object.

=over

=item PERL API

  $data = $model->description();

=item REST API

B<Request Method>

GET

B<Requires Authentication>

No

B<Parameters>

A class and object ID.

B<Returns>

=over 4

=item *

200 OK and JSON, HTML, or XML

=item *

404 Not Found

=back

B<Request example>

curl -H content-type:application/json http://api.wormbase.org/rest/field/[CLASS]/[OBJECT]/description

B<Response example>

<div class="response-example"></div>

=back

=cut

# Template: [% description %]

has 'description' => (
    is         => 'ro',
    required => 1,
    lazy     => 1,
    builder  => '_build_description',
);

# the following is a candidate for retrofitting with ModelMap
sub _build_description {
    my ($self) = @_;
    my $object = $self->object;
    my $class  = $object->class;
    my $tag;
    if ($class eq 'Sequence') {
        $tag = 'Title';
    }
    elsif ($class eq 'Expr_pattern') {
        $tag = 'Pattern'; # does nto handle Mohler movies (~~ 'Author' =~ /Mohler/)
    }
    else {
        $tag = 'Description';
    }
    # do many models have multiple description values?
    my $description ;
    if($class eq 'Phenotype'){
      my @array =map {{text=>"$_",evidence=>$self->_get_evidence($_)}}  @{$self ~~ "\@$tag"} ;
      $description = @array? \@array:undef;
    }else{
	$description = eval {join('<br />', $object->$tag)} || undef;
    }
    return {
        description => "description of the $class $object",
        data        => $description,
    };

    ## deal with evidence... ?
    #    my $data = { description => "description of the $class $object",
    #		 data        => { description => $description ,
    #				  evidence    => { check=>$self->check_empty($description),
    #						   tag=>"Description",
    #				  },
    #		 }
    #    };
    #   return $data;

}


=head3 laboratory

This method returns a data structure containing
the lab affiliation or origin of the requested object,
as well as the current lab representative.

=over

=item PERL API

 $data = $model->laboratory();

=item REST API

B<Request Method>

GET

B<Requires Authentication>

No

B<Parameters>

A class and object ID.

B<Returns>

=over 4

=item *

200 OK and JSON, HTML, or XML

=item *

404 Not Found

=back

B<Request example>

curl -H content-type:application/json http://api.wormbase.org/rest/field/[CLASS]/[OBJECT]/laboratory

B<Response example>

<div class="response-example"></div>

=back

=cut

# Template: [% laboratory %]

has 'laboratory' => (
    is         => 'ro',
    required => 1,
    lazy     => 1,
    builder  => '_build_laboratory',
);

# laboratory: Whenever a cross-ref to lab is needed.
# Returns the lab as well as the current representative.
# Used in: Person, Gene_class, transgene
# template: shared/fields/laboratory.tt2
sub _build_laboratory {
    my ($self) = @_;
    my $object = $self->object;
    my $class  = $object->class;    # Ace::Object class, NOT ext. model class

    my $WB2ACE_MAP = WormBase::API::ModelMap->WB2ACE_MAP->{laboratory};

    my $tag = $WB2ACE_MAP->{$class} || 'Laboratory';

    my @data;

    if (eval {$object->$tag}) {
	foreach my $lab ($object->$tag) {
	    my $label = $lab->Mail || "$lab";
	    my @representative = $lab->Representative;
        @representative = map { $self->_pack_obj($_) } @representative;
	    push @data, {
		laboratory => $self->_pack_obj($lab, "$label"),
		representative => \@representative
	    };
	}
    }
    my $description = "$class" =~ /Person/i ? "the laboratory associated with the $class"
        : "the laboratory where the $class was isolated, created, or named";
    return {
        description => $description,
        data        => @data ? \@data : undef,
    };
}

=head3 method

This method will return a data structure containing
the method used to describe or determine the object.

=over

=item PERL API

 $data = $model->method();

=item REST API

B<Request Method>

GET

B<Requires Authentication>

No

B<Parameters>

a class and object ID

B<Returns>

=over 4

=item *

200 OK and JSON, HTML, or XML

=item *

404 Not Found

=back

B<Request example>

curl -H content-type:application/json http://api.wormbase.org/rest/field/[CLASS]/[OBJECT]/method

B<Response example>

<div class="response-example"></div>

=back

=cut

# Template: [% method %]

has 'method' => (
    is       => 'ro',
    required => 1,
    lazy     => 1,
    builder  => '_build_method',
);

# The method used to describe the object
sub _build_method {
    my ($self) = @_;
    my $object = $self->object;
    my $class  = $object->class;
    my $method = $object->Method; # TODO: expand on this by pulling data from ?Method?

    return {
        description => "the method used to describe the $class",
        data        => $method && "$method",
    };
}

=head3 phenotypes

This method will return phenotypes associated with the object.

=over

=item PERL API

 $data = $model->phenotypes();

=item REST API

B<Request Method>

GET

B<Requires Authentication>

No

B<Parameters>

An RNAi id (eg WBRNAi00000001)

B<Returns>

=over 4

=item *

200 OK and JSON, HTML, or XML

=item *

404 Not Found

=back

B<Request example>

curl -H content-type:application/json http://api.wormbase.org/rest/field/rnai/WBRNAi00000001/phenotypes

B<Response example>

<div class="response-example"></div>

=back

=cut

has 'phenotypes' => (
    is       => 'ro',
    required => 1,
    lazy     => 1,
    builder  => '_build_phenotypes',
);

## method to build data

sub _build_phenotypes {
	my $self = shift;
	my $data = $self->_build_phenotypes_data('Phenotype');
	return {
		data => @$data ? $data : undef,
		description =>'phenotypes annotated with this term',
	};
}

=head3 phenotypes_not_observed

This method will return a data structure containing
phenotypes specifically NOT observed in the object (RNAi, Variation, etc).

=over

=item PERL API

 $data = $model->phenotypes_not_observed();

=item REST API

B<Request Method>

GET

B<Requires Authentication>

No

B<Parameters>

An RNAi id (eg WBRNAi00000001), a Variation ID (eg WBVar001441331), etc.

B<Returns>

=over 4

=item *

200 OK and JSON, HTML, or XML

=item *

404 Not Found

=back

B<Request example>

curl -H content-type:application/json http://api.wormbase.org/rest/field/rnai/WBRNAi00000001/phenotypes_not_observed

B<Response example>

<div class="response-example"></div>

=back

=cut

has 'phenotypes_not_observed' => (
    is       => 'ro',
    required => 1,
    lazy     => 1,
    builder  => '_build_phenotypes_not_observed',
);


sub _build_phenotypes_not_observed {
	my $self = shift;
	my $data = $self->_build_phenotypes_data('Phenotype_not_observed');
	return {
		data => @$data ? $data : undef,
		description =>'phenotypes NOT observed or associated with this object' };
}

sub _build_phenotypes_data {
    my $self = shift;
    my $tag = shift;
    my $object = $self->object;
#     $tag = '@'.$tag;
    return [ map {
        my $desc = $_->Description;
        my $remark = $_->Remark;
        my $ev = $self->_get_evidence($_);
        {
            phenotype   => $self->_pack_obj($_),
            evidence => $ev ? {evidence => $ev} : undef,
            description => $desc    && "$desc",
            remarks     => $remark && "$remark",
        };
    } @{$self ~~ '@'.$tag} ];
}


# TH: This was pulled (and still exists) in Variation.pm.
# It should be folded into _build_phenotypes_data above.
# Once complete, the varaition/phenotypes.tt2 template can (probably) be deleted.
# See also the phenotype processing in Gene.pm
sub _pull_phenotype_data {
    my ($self, $phenotype_tag) = @_;
    my $object = $self->object;

    my @phenotype_data; ## return data structure contains set of : not, phenotype_id; array ref for each characteristic in each element

        #my @phenotype_tags = ('Phenotype', 'Phenotype_not_observed');
        #foreach my $phenotype_tag (@phenotype_tags) {
    my @phenotypes = $object->$phenotype_tag;

    foreach my $phenotype (@phenotypes) {
        my %p_data; ### data holder for not, phenotype, remark, and array ref of characteristics, loaded into @phenotype_data for each phenotype related to the variation.
        my @phenotype_subtags = $phenotype->col ; ## 0

        my @psubtag_data;
        my @ps_data;

        my %tagset = (
            'Paper_evidence' => 1,
            'Remark' => 1,
            #                   'Person_evidence' => 1,
            #             'Phenotype_assay' => 1,
            #             'Penetrance' => 1,
            #             'Temperature_sensitive' => 1,
            #             'Anatomy_term' => 1,
            #             'Recessive' => 1,
            #             'Semi_dominant' => 1,
            #             'Dominant' => 1,
            #             'Haplo_insufficient' => 1,
            #             'Loss_of_function' => 1,
            #             'Gain_of_function' => 1,
            #             'Maternal' => 1,
            #             'Paternal' => 1

	    ); ### extra data commented out off data pull system 20090922 to simplify table build and data pull

        my %extra_tier = (
            Phenotype_assay       => 1,
            Temperature_sensitive => 1,
            # Penetrance => 1,
	    );

        my %gof_set = (
            Gain_of_function => 1,
            Maternal         => 1,
            # Paternal => 1,
	    );

        my %no_details = (
            Recessive          => 1,
            Semi_dominant      => 1,
            Dominant           => 1,
            Haplo_insufficient => 1,
            Paternal           => 1,
            # Loss_of_function => 1,
            # Gain_of_function => 1,
	    );

        foreach my $phenotype_subtag (@phenotype_subtags) {
	    if (!($tagset{$phenotype_subtag})) {
		next;
	    }
	    else {
		my @ps_column = $phenotype_subtag->col;

                                ## data to be incorporated into @ps_data;

		my $character;
		my $remark;
		my $evidence_line;

                                ## process Penetrance data
		if ($phenotype_subtag =~ m/Penetrance/) {
                    foreach my $ps_column_element (@ps_column) {
                        if ($ps_column_element =~ m/Range/) {
                            next;
                        }
                        else {
                            my ($char,$text,$evidence) = $ps_column_element->row;
                            my @pen_evidence = $evidence-> col;
                            $character = "$phenotype_subtag"; #\:
                            $remark = $char;                  #$text

                            my @pen_links = eval {map {format_reference(-reference=>$_,-format=>'short') if $_;} @pen_evidence}; # ;

                            $evidence_line =  join "; ", @pen_links;
                        }
                    }
		}
		elsif ($phenotype_subtag =~ m/Remark/) { # get remark
                    my @remarks = $phenotype_subtag->col;
                    my $remarks = join "; ", @remarks;
                    my $details_url = "/db/misc/etree?name=$phenotype;class=Phenotype";
                    my $details_link = qq(<a href="$details_url">[Details]>);
                    $remarks = "$remarks\ $details_link";
                    $p_data{'remark'} = $remarks; #$phenotype_subtag->right
                    next;
		}
		elsif ($phenotype_subtag =~ m/Paper_evidence/) { ## get evidences
                    my @phenotype_paper_evidence = $phenotype_subtag->col;
                    my @phenotype_paper_links = eval {map {format_reference(-reference=>$_,-format=>'short') if $_;} @phenotype_paper_evidence}; #;
                    $p_data{'paper_evidence'} = join "; ", @phenotype_paper_links;
                    next;
		}
		elsif ($phenotype_subtag =~ m/Anatomy_term/) { ## process Anatomy_term data
                    my ($char,$text,$evidence) = $phenotype_subtag ->row;
                    my @at_evidence = $phenotype_subtag -> right -> right -> col;

                    # my $at_link;
                    my $at_term = $text->Term;
                    my $at_url = "/db/ontology/anatomy?name=" . $text;
                    my $at_link = a({-href => $at_url}, $at_term);

                    $character = $char;
                    $remark = $at_link; #$text

                    my @at_links = eval {map {format_reference(-reference=>$_,-format=>'short') if $_;} @at_evidence}; #;

                    $evidence_line = join "; ", @at_links;

		}
		elsif ($phenotype_subtag =~ m/Phenotype_assay/) { ## process extra tier data
                    foreach my $character_detail (@ps_column) {
                        my $cd_info = $character_detail->right; # right @cd_info
                        my @cd_evidence = $cd_info->right->col;
                        $character = "$character_detail"; #$phenotype_subtag\:
                        # = $cd_info->col;
                        $remark =  $cd_info; # join "; ", @cd_info;

                        my @cd_links= eval {map {format_reference(-reference=>$_,-format=>'short') if $_;} @cd_evidence }; #  ;

                        $evidence_line = join "; ", @cd_links;

                        my $phenotype_st_line = join "|", ($phenotype_subtag,$character,$remark,$evidence_line);
                        push  @ps_data, $phenotype_st_line ;
                    }
                    next;
		}
		elsif ($phenotype_subtag =~ m/Temperature_sensitive/) {
		    foreach my $character_detail (@ps_column) {
                        my $cd_info = $character_detail->right;
                        my @cd_evidence = $cd_info->right->col;

                        my @cd_links = eval {map {format_reference(-reference=>$_,-format=>'short') if $_;} @cd_evidence }; #  ;

                        $character = "$character_detail"; #$phenotype_subtag\:
                        $remark = $cd_info;
                        $evidence_line = join "; ", @cd_links ;

                        my $phenotype_st_line = join "|", ($phenotype_subtag,$character,$remark,$evidence_line);
                        push  @ps_data, $phenotype_st_line ;
                    }

                    next;
		}
		elsif ( $phenotype_subtag =~ m/Gain_of_function/) { # $gof_set{}
                    my ($char,$text,$evidence) = $phenotype_subtag->row;
                    my @gof_evidence;

                    eval{
                        @gof_evidence = $evidence-> col;
                    };
                    #\:
                    $remark = $text; #$char

                    if (!(@gof_evidence)) {
                        $character = $phenotype_subtag;
                        $remark = '';
                        $evidence_line = $p_data{'paper_evidence'};
                    }
                    #my @pen_links = map {format_reference(-reference=>$_,-format=>'short');} @pen_evidence;
                    else {
                        $character = $phenotype_subtag;
                        $remark = $char;
                        my @gof_paper_links = eval {map {format_reference(-reference=>$_,-format=>'short') if $_;} @gof_evidence}; #  ;

                        $evidence_line =  join "; ", @gof_paper_links;
                    }
                    my $phenotype_st_line = join "|", ($phenotype_subtag,$character,$remark,$evidence_line);
                    push  @ps_data, $phenotype_st_line ;
                    next;
		}
		elsif ( $phenotype_subtag =~ m/Loss_of_function/) { # $gof_set{}
                    my ($char,$text,$evidence) = $phenotype_subtag->row;
                    my @lof_evidence;

                    eval{
                        @lof_evidence = $evidence-> col;
                    };
                    #\:
                    $remark = $text; #$char

                    if (!(@lof_evidence)) {
                        $character = $phenotype_subtag;
                        $remark = $text;
                        $evidence_line = $p_data{'paper_evidence'};
                    }
                    #my @pen_links = map {format_reference(-reference=>$_,-format=>'short');} @pen_evidence;
                    else {
                        $character = $phenotype_subtag;
                        $remark = $text;
                        my @lof_paper_links = eval {map {format_reference(-reference=>$_,-format=>'short') if $_;} @lof_evidence}; ; #

                        $evidence_line =  join "; ", @lof_paper_links;
                    }
                    my $phenotype_st_line = join "|", ($phenotype_subtag,$character,$remark,$evidence_line);
                    push  @ps_data, $phenotype_st_line ;
                    next;

		}
		elsif ( $phenotype_subtag =~ m/Maternal/) { # $gof_set{}
                    my ($char,$text,$evidence) = $phenotype_subtag->row;

                    my @mom_evidence;

                    eval {

                        @mom_evidence = $evidence->col;

                    };

                    if (!(@mom_evidence)) {
                        $character = $phenotype_subtag;
                        $remark = '';
                        $evidence_line = $p_data{'paper_evidence'};
                    }
                    else {
                        $character = $phenotype_subtag;
                        $remark = '';
                        my @mom_paper_links = eval{map {format_reference(-reference=>$_,-format=>'short') if $_;} @mom_evidence} ; #;
                        $evidence_line =  join "; ", @mom_paper_links;

                    }

                    my $phenotype_st_line = join "|", ($phenotype_subtag,$character,$remark,$evidence_line);
                    push  @ps_data, $phenotype_st_line ;
                    next;
		}
		elsif ($no_details{$phenotype_subtag}) { ## process no details data
                    my @nd_evidence;
                    eval {
                        @nd_evidence = $phenotype_subtag->right->col;
                    };

                    $character = $phenotype_subtag;
                    $remark = "";
                    if (@nd_evidence) {

                        my @nd_links = eval{map {format_reference(-reference=>$_,-format=>'short') if $_;} @nd_evidence ; }; #

                        $evidence_line = join "; ", @nd_links;
                    }
		}

		my $phenotype_st_line = join "|", ($phenotype_subtag,$character,$remark,$evidence_line);
		push  @ps_data, $phenotype_st_line ; ## let @ps_data evolve to include characteristic; remarks; and evidence line
	    }

        }

        #my $phenotype_url = Object2URL($phenotype);
        #my $phenotype_link = b(a({-href=>$phenotype_url},$phenotype_name));


        if ($phenotype_tag eq 'Phenotype_not_observed') {
            $p_data{not} = 1;
        }

        $p_data{phenotype} = $self->_pack_obj($phenotype);

        $p_data{ps} = @ps_data ? \@ps_data : undef;

        push @phenotype_data, \%p_data;
    }

    return {
        description => 'Phenotypes for this variation',
        data        => @phenotype_data ? \@phenotype_data : undef,
    };
}








=head3 references

Currently, the WormBase web app uses a custom search
to retrieve references. This method will return
references directly cross-referenced to the current
object.

=over

=item PERL API

 $data = $model->references();

=item REST API

B<Request Method>

GET

B<Requires Authentication>

No

B<Parameters>

a class and object ID

B<Returns>

=over 4

=item *

200 OK and JSON, HTML, or XML

=item *

404 Not Found

=back

B<Request example>

curl -H content-type:application/json http://api.wormbase.org/rest/field/[CLASS]/[OBJECT]/references

B<Response example>

<div class="response-example"></div>

=back

=cut

# Template: Currently none. Method provided for API users.

has 'references' => (
    is       => 'ro',
    required => 1,
    lazy     => 1,
    builder  => '_build_references',
);


sub _build_references {
    my $self   = shift;
    my $object = $self->object;
    # Could also use ModelMap...
    my $tag = $object->at('Reference') || $object->at('Paper') || '';
    my @references = $object->$tag if $tag;
    @references = map { $self->_api->xapian->fetch({ id => "$_", class => 'paper', fill => 1}) } @references;
    return { description => 'references associated with this object',
             data        => @references ? \@references : undef };
}

=head3 remarks

This method will return a data structure containing
curator remarks about the requested object.

=over

=item PERL API

 $data = $model->remarks();

=item REST API

B<Request Method>

GET

B<Requires Authentication>

No

B<Parameters>

a class and object ID

B<Returns>

=over 4

=item *

200 OK and JSON, HTML, or XML

=item *

404 Not Found

=back

B<Request example>

curl -H content-type:application/json http://api.wormbase.org/rest/field/[CLASS]/[OBJECT]/remarks

B<Response example>

<div class="response-example"></div>

=back

=cut

# Template: [% remarks %]

has 'remarks' => (
    is       => 'ro',
    required => 1,
    lazy     => 1,
    builder  => '_build_remarks',
);

sub _build_remarks {
    my ($self) = @_;
    my $object = $self->object;

    my @remarks = $object->get('Remark');
    @remarks = $object->get('Comment') unless @remarks;
    @remarks = (@remarks, ($object->get('DB_remark')));

    my $class   = $object->class;

    @remarks = grep { !/phenobank/ } @remarks if($class =~ /^RNAi$/i);
    @remarks = map { { text => "$_", evidence =>$self->_get_evidence($_)} } @remarks; # stringify them

    return {
        description => "curatorial remarks for the $class",
        data        => @remarks ? \@remarks : undef,
    };
}

=head3 summary

This method will return a data structure containing
a brief summary of the requested object.

=over

=item PERL API

 $data = $model->summary();

=item REST API

B<Request Method>

GET

B<Requires Authentication>

No

B<Parameters>

A class and object ID.

B<Returns>

=over 4

=item *

200 OK and JSON, HTML, or XML

=item *

404 Not Found

=back

B<Request example>

curl -H content-type:application/json http://api.wormbase.org/rest/field/[CLASS]/[OBJECT]/summary

B<Response example>

<div class="response-example"></div>

=back

=back

=cut

# Template: [% summary %]

has 'summary' => (
    is       => 'ro',
    required => 1,
    lazy     => 1,
    builder  => '_build_summary',
);

sub _build_summary {
    my ($self)  = @_;
    my $object  = $self->object;
    my $class   = $object->class;
    my $summary = $object->Summary;

    return {
        description => "a brief summary of the $class:$object",
        data        => $summary && "$summary",
    };
}

=head3 status

This method will return a data structure containing
the current status of the object.

=over

=item PERL API

 $data = $model->status();

=item REST API

B<Request Method>

GET

B<Requires Authentication>

No

B<Parameters>

a class and object ID

B<Returns>

=over 4

=item *

200 OK and JSON, HTML, or XML

=item *

404 Not Found

=back

B<Request example>

curl -H content-type:application/json http://api.wormbase.org/rest/field/[CLASS]/[OBJECT]/status

B<Response example>

<div class="response-example"></div>

=back

=cut

# Template: [% status %]

has 'status' => (
    is       => 'ro',
    lazy     => 1,
    required => 1,
    builder  => '_build_status',
);

sub _build_status {
    my ($self) = @_;
    my $object = $self->object;
    my $class  = $object->class;
    my $status = $class eq 'Protein' ? $object->Live
	: (eval{$object->Status} ? $object->Status : 'unverified');

    return {
        description => "current status of the $class:$object if not Live or Valid",
        data        => $status && (($status eq 'Live' || $status eq 'Valid') ? undef : "$status"),
    };
}

=head3 taxonomy

This method will return a data structure containing
the genus and species of the requested object.

=over

=item PERL API

 $data = $model->taxonomy();

=item REST API

B<Request Method>

GET

B<Requires Authentication>

No

B<Parameters>

a class and object ID

B<Returns>

=over 4

=item *

200 OK and JSON, HTML, or XML

=item *

404 Not Found

=back

B<Request example>

curl -H content-type:application/json http://api.wormbase.org/rest/field/[CLASS]/[OBJECT]/taxonomy

B<Response example>

<div class="response-example"></div>

=back

=cut

# Template: [% taxonomy %]

has 'taxonomy' => (
    is       => 'ro',
    required => 1,
    lazy     => 1,
    builder  => '_build_taxonomy',
);

# Parse out species "from a Genus species" string.
sub _build_taxonomy {           # this overlaps with parsed_species
    my ($self) = @_;

    my $spec = $self->ace_dsn->raw_fetch($self->object, 'Species');
    my ($genus, $species) = ($spec ? $spec =~ /(.*) (.*)/ : qw(Caenorhabditis elegans));

    return {
        description => 'the genus and species of the current object',
        data        => $genus && $species && {
            genus   => $genus,
            species => $species,
        },
    };
}

=head3 xrefs

This method will return a data structure containing
external database cross-references for the requested object.

=over

=item Perl API

 $data = $model->xrefs();

=item REST API

B<Request Method>

GET

B<Requires Authentication>

No

B<Parameters>

A class and object ID.

B<Returns>

=over 4

=item *

200 OK and JSON, HTML, or XML

=item *

404 Not Found

=back

B<Request example>

curl -H content-type:application/json http://api.wormbase.org/rest/field/CLASS/OBJECT/xrefs

B<Response example>

<div class="response-example"></div>

=cut

# template [% xrefs %]

has 'xrefs' => (
    is       => 'rw',
    required => 1,
    lazy     => 1,
    builder  => '_build_xrefs',
);

# XREFs are stored under the Database tag.
sub _build_xrefs {
    my ($self,$object) = @_;
    $object = $self->object unless $object;

    my @databases = $object->Database;
    my %dbs;
    foreach my $db (@databases) {
        # Possibly multiple entries for a single DB
      $dbs{$db} = $db->col ? {} : undef;
      foreach my $dbt ($db->col){
        @{$dbs{$db}{$dbt}{ids}} = map {( $_ =~ /^(OMIM:|GI:)(.*)/ ) ? "$2" : "$_";} $dbt->col;
      }
    }

    return {
        description => 'external databases and IDs containing additional information on the object',
        data        => %dbs ? \%dbs : undef,
    };
}

has 'used_for' => (
    is       => 'ro',
    lazy     => 1,
    builder  => '_build__used_for',
);

sub _build__used_for {
    my ($self) = @_;
    my $object = $self->object;
    my @data;
    foreach my $type ($object->Used_for){
        (my $type_name = "$type") =~ s/_/ /;
        my @entries = map {
            my @labs = eval {  map { $self->_pack_obj($_) } $_->Laboratory; };
            {
                used_in_type => $type_name,
                used_in      => $self->_pack_obj($_),
                use_summary  => eval { $_->Summary . ""} || undef,
                use_lab      => \@labs,
            };
        } $object->$type;
        push @data, @entries;
    }

    my $class_name = $object->class;
    return {
        description => "The $class_name is used for",
        data        => @data ? \@data : undef };
}



#################################################
#
#   Convenience methods
#
################################################


sub mysql_dsn {
    my ($self, $source) = @_;
    return $self->dsn->{"mysql_" . $source};
}

sub gff_dsn {
    my ($self, $species) = @_;
    $species ||= $self->_parsed_species;
    $species =~ s/^all$/c_elegans/;
    $self->log->debug("getting gff database species $species");
    my $gff = $self->dsn->{"gff_" . $species} || $self->dsn->{"gff_c_elegans"};
    die "Can't find gff database for $species, host:" . $self->host unless $gff;
    return $gff;
}

sub ace_dsn {
    my ($self) = @_;
    return $self->dsn->{"acedb"};
}


# No longer using NFS because of piss-poor performance.
# So I'll need to associate a back end node with the dynamic image.
# Is this ONLY used by blast_blat?
sub tmp_image_dir {
    my $self = shift;

# 2010.08.18: hostname no longer required in URI; tmp images stored in NFS mount
# Include the hostname for images. Necessary for proxying and apache configuration.
#    my $host = `hostname`;
#    chomp $host;
#    $host ||= 'local';
#    my $path = $self->tmp_dir('media/images',$host,@_);

    my $path = $self->tmp_dir('media/images', @_);
    return $path;
}

# Create a URI to a temporary image.
# Routing will be handled by Static::Simple in development
# and apache in production.
sub tmp_image_uri {
    my ($self, $path_and_file) = @_;

#    # append the hostname so that I can correctly direct traffic through the proxy
#    my $host = `hostname`;
#    chomp $host;
#    $host ||= 'local';

    my $tmp_base = $self->tmp_base;

# Purge the temp base from the path_and_file
# pre-NFS: eg /tmp/wormbase/images/wb-web1/00/00/00/filename.jpg -> images/wb-web1/00/00/00/filename.jpg
# eg /tmp/wormbase/images/00/00/00/filename.jpg -> images/00/00/00/filename.jpg
    $path_and_file =~ s/$tmp_base//;

    # URI (pre-NFS): /images/wb-web1/00/00/00...
    # URI: /images/00/00/00...
    my $uri = ($path_and_file=~m/^\//)? $path_and_file :'/' . $path_and_file;
    return $uri;
}

sub tmp_acedata_dir {
    my $self = shift;
    return $self->tmp_dir('acedata', @_);
}

# A simple array would probably suffice instead of a hash
# (which is used in the view for sorting).
# We could sort objects in view according to name key
# supplied by _pack_obj but might be messy to change now.
sub _pack_objects {
    my ($self, $objects) = @_;
#    $objects = ref $objects ? $objects : [ $objects ];
    return unless $objects;
    return {map {$_ => $self->_pack_obj($_)} @$objects};
}

# Alternative to _pack_objects
# _pack_objects has problem with cell_content MACRO in template,
# which use hash exclusively for key-value content,
# a list is required for list type of content
sub _pack_list {
    my ($self, $objects, %args) = @_;
    my ($sort, $comparison_sub) = @args{('sort', 'comparison_subroutine')};

    return unless $objects;
    my @packed_objects = map { $self->_pack_obj($_) } @$objects;

    # sorting is disabled by default for performance reason;
    # it can be enbale by specify EITHER of $sort (a boolean flag) OR
    # $comparison_sub (a subroutine)
    if ($sort || $comparison_sub) {
        $comparison_sub = $comparison_sub || sub { lc($_[0]->{label}) };
        @packed_objects = sort { $comparison_sub->($a) cmp $comparison_sub->($b) } @packed_objects;
    }
    return @packed_objects;
}

## 	Parameters:
#	object: the Ace::Object to be linked to
#	(label): link text
sub _pack_obj {
    my ($self, $object, $label, %args) = @_;
    return undef unless $object; # this method shouldn't expect a list.
    return $object unless (ref($object) eq 'Ace::Object' ||
                           ref($object) eq 'Ace::Object::Wormbase');

    my $wbclass = WormBase::API::ModelMap->ACE2WB_MAP->{class}->{$object->class};
    $label = $label // $self->_make_common_name($object);
    return {
        id       => "$object",
        label    => "$label",
        class    => lc($wbclass || $object->class),
        taxonomy => $self->_parsed_species($object),
        %args,
    };
}

sub _parsed_species {
    my ($self, $object) = @_;
    $object ||= $self->object;

    if (my $genus_species = $self->ace_dsn->raw_fetch($object, 'Species')) {
        my ($g, $species) = $genus_species =~ /(.).*[ _](.+)/o;
        return lc "${g}_$species";
    }

    return 'all';
}

# Take a string of Genus species and return a
# data structure suitable for marking up species in the view.

sub _split_genus_species {
    my ($self,$string) = @_;
    my ($genus,$species) = split(/\s/,$string);
    return { genus => $genus, species => $species };
}



############################################################
#
# Private Methods
#
############################################################


# Description: checks data returned by external model for standards
#              compliance and fixes the data if necessary and possible.
#              the fixing is very rudimentary and can be bypassed by intra-model
#              invocations of methods. do not depend on it. fix your model code.
#              WARNING: modifies data directly if passed data is reference
# Usage: if (my ($fixed, @problems) = $self->_check_data($data)) { ... }
# Returns: () if all is well, otherwise array with fixed data and
#          description(s) of compliance problem(s).
sub _check_data {
    my ($self, $data, $class) = @_;
    $class ||= '';
    my @compliance_problems;

    if (ref($data) ne 'HASH') {   # no data pack
        $data = {
            description => 'No description available',
            data        => $data,
        };
        push @compliance_problems,
          'Did not return in hashref datapack with description and data entry.';
    }
    elsif (!$data->{description} && !exists $data->{data}) { # it's probably a data hash but not packed
        $data = {
            description => 'No description available',
            data        => $data,
        };
        push @compliance_problems,
          'Returned hashref, but no data & description entries. Perhaps forgot to pack the data?';
    }
    elsif (!$data->{description}) { # data value is there, but no description
        $data->{description} = 'No description available';
        push @compliance_problems,
          'Datapack does not have description.';
    }

    if (!exists $data->{data}) {    # no data entry
        $data->{data} = undef;
        push @compliance_problems, 'No data entry in datapack.';
    }
    elsif (my ($tmp, @problems) = $self->_check_data_content($data->{data}, $class))
    {
        $data->{data} = $tmp;
        push @compliance_problems, @problems;
    }

    return @compliance_problems ? ($data, @compliance_problems) : ();
}

# Description: helper to recursively checks the content of data for standards
#              compliance and fixes the data if necessary and possible
# Usage: FOR INTERNAL USE.
#        if(my ($tmp) = $self->_check_data_content($datum)) { ... }
# Returns: if all is well, (). otherwise, 2-array with fixed data and
#          description(s) of compliance problem(s).
sub _check_data_content {
    my ($self, $data, @keys) = @_;
    my $ref = ref($data) || return ();

    my @compliance_problems;
    my ($tmp, @problems);
    if ($ref eq 'ARRAY') {
        foreach (@$data) {
            if (($tmp, @problems) = $self->_check_data_content($_, @keys))
            {
                $_ = $tmp;
                push @compliance_problems, @problems;
            }
        }
        unless (@$data) {
            push @compliance_problems,
              join('->', @keys)
              . ': Empty arrayref returned; should be undef.';
        }
    }
    elsif ($ref eq 'HASH') {
        foreach my $key (keys %$data) {
            if (($tmp, @problems) =
                $self->_check_data_content($data->{$key}, @keys, $key))
            {
                $data->{$key} = $tmp;
                push @compliance_problems, @problems;
            }
        }
        unless (%$data) {
            push @compliance_problems,
              join('->', @keys)
              . ': Empty hashref returned; should be undef.';
        }
    }
    elsif ($ref eq 'SCALAR' || $ref eq 'REF') {

        # make sure scalar ref doesn't refer to something bad
        if (($tmp, @problems) = $self->_check_data_content($$data, @keys))
        {
            $data = $tmp;
            push @compliance_problems, @problems;
        }
        else {
            $data =
              $$data;    # doesn't refer to anything bad -- just dereference it.
            push @compliance_problems,
              join('->', @keys)
              . ': Scalar reference returned; should be scalar.';
        }

    }
    elsif (eval {$data->isa('Ace::Object')} || eval {$data->isa('Ace::Object::Wormbase')}) {
        push @compliance_problems,
            join('->', @keys)
          . ": Ace::Object (class: "
          . $data->class
          . ", name: $data) returned.";
        $data =
          $data->name;  # or perhaps they wanted a _pack_obj... we'll never know
    }
    else {    # don't know what the data is, but try to stringify it...
        push @compliance_problems,
            join('->', @keys)
          . ": Object (class: "
          . ref($data)
          . ", value: $data) returned.";
        $data = "$data";
    }

    return @compliance_problems ? ($data, @compliance_problems) : ();
}



############################################################
#
# Methods provided as a convenience for API users.
# Not used directly as part of the webapp.
#
############################################################

################################################
#   REFERENCES
################################################

sub _get_references {
  my ($self,$filter) = @_;
  my $object = $self->object;

  # References are not standardized. They may be under the Reference or Paper tag.
  # Dynamically select the correct tag - this is a kludge until these are defined.
  my $tag = (eval {$object->Reference}) ? 'Reference' : 'Paper';

  my $dbh = $self->ace_dsn;

  my $class = $object->class;
  my @references;
  if ( $filter eq 'all' ) {
      @references = $object->$tag;
  } elsif ( $filter eq 'gazette_abstracts' ) {
      @references = $dbh->fetch(
	  -query => "find $class $object; follow $tag WBG_abstract",
	  -fill  => 1);
  } elsif ( $filter eq 'published_literature' ) {
      @references = $dbh->fetch(
	  -query => "find $class $object; follow $tag PMID",
	  -fill => 1);

      #    @filtered = grep { $_->CGC_name || $_->PMID || $_->Medline_name }
      #      @$references;
  } elsif ( $filter eq 'meeting_abstracts' ) {
      @references = $dbh->fetch(
	  -query => "find $class $object; follow $tag Meeting_abstract",
	  -fill => 1
	  );
  } elsif ( $filter eq 'wormbook_abstracts' ) {
      @references = $dbh->fetch(
	  -query => "find $class $object; follow $tag WormBook",
	  -fill => 1
	  );
      # Hmm.  I don't know how to do this yet...
      #    @filtered = grep { $_->Remark =~ /.*WormBook.*/i } @$references;
  }
  return \@references;
}

# This is a convenience method for returning all methods. It
# isn't a field itself and is not included in the References widget.
sub all_references {
    my $self = shift;
    my $references = $self->_get_references('all');
    my $result = { description => 'all references for the object',
		   data        => $references,
    };
    return $result;
}

sub published_literature {
    my $self = shift;
    my $references = $self->_get_references('published_literarture');
    my $result = { description => 'published references only, no abstracts',
		   data        => $references,
    };
    return $result;
}

sub meeting_abstracts {
    my $self = shift;
    my $references = $self->_get_references('meeting_abstracts');
    my $result = { description => 'meeting abstracts',
		   data        => $references,
    };
    return $result;
}

sub gazette_abstracts {
    my $self = shift;
    my $references = $self->_get_references('gazette_abstracts');
    my $result = { description => 'gazette abstracts',
		   data        => $references,
    };
    return $result;
}

sub wormbook_abstracts {
    my $self = shift;
    my $references = $self->_get_references('wormbook_abstracts');
    my $result = { description => 'wormbook abstracts',
		   data        => $references,
    };
    return $result;
}

sub _get_genotype {
    my ($self, $object) = @_;
    my $genotype = $object->Genotype;

    my %elements;
    foreach my $tag ($object->Contains) {
        next if $tag eq 'Variation';
          map {
            $_ = $self->_pack_obj($_);
            $elements{$_->{label}} = $_;
          } $object->$tag;
    }

    return ($genotype || (keys %elements > 0) ) ? {
      str => $genotype && "$genotype",
      data => %elements ? \%elements : undef,
    } : undef;
}

#########################################
#
#   INTERNAL METHODS
#
#########################################
sub _fetch_gff_gene {
    my ($self,$transcript) = @_;

    my $trans;
    my $GFF = $self->gff_dsn() or die "Cannot connect to GFF database, host:" . $self->host; # should probably log this?

    ($trans) = $GFF->get_features_by_name("$transcript");
    return $trans;
}

#----------------------------------------------------------------------
# Returns count of objects to be returned with the given tag.
# If no tag is given, it counts the amount of objects in the next column.
# Arg[0]   : The AceDB object to interrogate.
# Arg[1]   : The AceDB schema location to count the amount of retrievable objects;
#
sub _get_count{
    my ($self, $obj, $tag) = @_;
    $obj = $obj->fetch;

    # get the first item in the tag
    my $first_item = $tag ? $obj->get($tag, 0) && $obj->get($tag, 0)->right : $obj->right;

    if($first_item->{'.raw'}){
        # get our current column location
        my $col = $first_item->{'.col'};

        # grep for rows that are objects
        my $curr;
        return scalar(  grep {  $curr = @{$_}[$col-1] if (@{$_}[$col-1]);
                                (@{$_}[$col] && ($curr eq "?tag?$tag?"));
                        } @{$first_item->{'.raw'}} );
    } else {
        # try to avoid this, breaks on larger items
        return $obj->get($tag, 0) ? scalar $obj->get($tag, 0)->col : 0;
    }
}


1;
