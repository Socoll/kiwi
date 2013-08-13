#================
# FILE          : KIWIProfileFile.pm
#----------------
# PROJECT       : openSUSE Build-Service
# COPYRIGHT     : (c) 2013 SUSE LLC
#               :
# AUTHOR        : Robert Schweikert <rjschwei@suse.com>
#               :
# BELONGS TO    : Operating System images
#               :
# DESCRIPTION   : This class collects all data needed to create the .profile
#               : file from the XML.
#               :
# STATUS        : Development
#----------------
package KIWIProfileFile;

#==========================================
# Modules
#------------------------------------------
use strict;
use warnings;

require Exporter;

#==========================================
# KIWI Modules
#------------------------------------------
use FileHandle;
use KIWIXML;
use KIWIXMLOEMConfigData;
use KIWIXMLPreferenceData;
use KIWIXMLTypeData;

#==========================================
# Exports
#------------------------------------------
our @EXPORT_OK = qw ();

#==========================================
# Constructor
#------------------------------------------
sub new {
	# ...
	# Create the KIWIProfileFile object
	# ---
	#==========================================
	# Object setup
	#------------------------------------------
	my $this  = {};
	my $class = shift;
	bless $this,$class;
	#==========================================
	# Object data
	#------------------------------------------
	my $kiwi = KIWILog -> instance();
	my %supportedEntries = map { ($_ => 1) } qw(
		kiwi_allFreeVolume
		kiwi_bootloader
		kiwi_boot_timeout
		kiwi_cmdline
		kiwi_compressed
		kiwi_cpio_name
		kiwi_delete
		kiwi_devicepersistency
		kiwi_displayname
		kiwi_drivers
		kiwi_firmware
		kiwi_fsmountoptions
		kiwi_hwclock
		kiwi_hybrid
		kiwi_hybridpersistent
		kiwi_iname
		kiwi_installboot
		kiwi_iversion
		kiwi_keytable
		kiwi_language
		kiwi_loader_theme
		kiwi_luks
		kiwi_lvm
		kiwi_lvmgroup
		kiwi_oemalign
		kiwi_oemataraid_scan
		kiwi_oembootwait
		kiwi_oemkboot
		kiwi_oempartition_install
		kiwi_oemreboot
		kiwi_oemrebootinteractive
		kiwi_oemrecovery
		kiwi_oemrecoveryID
		kiwi_oemrecoveryInPlace
		kiwi_oemrootMB
		kiwi_oemshutdown
		kiwi_oemshutdowninteractive
		kiwi_oemsilentboot
		kiwi_oemsilentinstall
		kiwi_oemsilentverify
		kiwi_oemswap
		kiwi_oemswapMB
		kiwi_oemtitle
		kiwi_oemunattended
		kiwi_oemunattended_id
		kiwi_profiles
		kiwi_ramonly
		kiwi_revision
		kiwi_showlicense
		kiwi_size
		kiwi_splash_theme
		kiwi_strip_delete
		kiwi_strip_libs
		kiwi_strip_tools
		kiwi_testing
		kiwi_timezone
		kiwi_type
		kiwi_xendomain
	);
	#==========================================
	# Store member data
	#------------------------------------------
	$this->{kiwi} = $kiwi;
	$this->{vars} = \%supportedEntries;
	return $this;
}

#==========================================
# addEntry
#------------------------------------------
sub addEntry {
	# ...
	# Add an entry to the profile data. If the value is empty
	# an existing entry will be deleted. the onus is on the
	# client to avoid duplicates in the data
	# ---
	my $this  = shift;
	my $key   = shift;
	my $value = shift;
	my $kiwi  = $this->{kiwi};
	if (! $key) {
		my $msg = 'addEntry: expecting a string as first argument';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return;
	}
	if (! defined $value) {
		delete $this->{profile}{$key};
	}
	my %allowedVars = %{$this->{vars}};
	if ((! $allowedVars{$key}) && ($key !~ /^kiwi_LVM_LV/msx)) {
		my $msg = "Unrecognized variable: $key";
		$kiwi -> warning ($msg);
		$kiwi -> skipped ();
		return $this;
	}
	if ($this->{profile}{$key}) {
		my $exist = $this->{profile}{$key};
		my $separator = q{ };
		if ($exist =~ /,/msx || $value =~ /,/msx) {
			$separator = q{,};
		}
		$this->{profile}{$key} = "$exist$separator$value";
	} else {
		$this->{profile}{$key} = $value;
	}
	return $this;
}

#==========================================
# updateFromXML
#------------------------------------------
sub updateFromXML {
	# ...
	# Update the existing data from an XML object.
	# the onus is on the client to avoid duplicates
	# in the data
	# ---
	my $this = shift;
	my $xml  = shift;
	my $kiwi = $this->{kiwi};
	if (! $xml || ref($xml) ne 'KIWIXML') {
		my $msg = 'updateFromXML: expecting KIWIXML object as first argument';
		$kiwi -> error($msg);
		$kiwi -> failed();
		return;
	}
	#==========================================
	# kiwi_drivers
	#------------------------------------------
	$this -> __updateXMLDrivers ($xml);
	#==========================================
	# kiwi_lvmgroup
	#------------------------------------------
	$this -> __updateXMLSystemDisk ($xml);
	#==========================================
	# kiwi_xendomain
	#------------------------------------------
	$this -> __updateXMLMachine ($xml);
	#==========================================
	# kiwi_oem*
	#------------------------------------------
	$this -> __updateXMLOEMConfig ($xml);
	# TODO: more to come
	return $this;
}

#==========================================
# updateFromHash
#------------------------------------------
sub updateFromHash {
	# ...
	# Update the existing data from an XML object.
	# the onus is on the client to avoid duplicates
	# in the data
	# ---
	my $this = shift;
	my $hash = shift;
	my $kiwi = $this->{kiwi};
	my $msg  = 'updateFromHash: ';
	if (! $hash || ref($hash) ne 'HASH') {
		$msg .= 'expecting HASH ref as first argument';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return;
	}
	$this->{profile} = $hash;
	return $this;
}

#==========================================
# writeProfile
#------------------------------------------
sub writeProfile {
	# ...
	# Write the profile data to the given path
	# ---
	my $this   = shift;
	my $target = shift;
	my $kiwi   = $this->{kiwi};
	my $msg    = 'KIWIProfileFile: ';
	if (!$target || ! -d $target) {
		$msg .= 'writeProfile expecting directory as argument';
		$kiwi -> error ($msg);
		$kiwi -> failed();
		return;
	}
	if ($this->{profile}) {
		$this -> __storeRevisionInformation();
		my %profile = %{$this->{profile}};
		my $PROFILE = FileHandle -> new();
		if (! $PROFILE -> open (">$target/.profile")) {
			$msg .= "Could not open '$target/.profile' for writing";
			$kiwi -> error($msg);
			$kiwi -> failed();
			return;
		}
		binmode ($PROFILE, ":encoding(UTF-8)");
		foreach my $key (sort keys %profile) {
			$kiwi -> loginfo ("[PROFILE]: $key=\"$profile{$key}\"\n");
			print $PROFILE "$key=\"$profile{$key}\"\n";
		}
		$PROFILE -> close();
		return 1;
	}
	$msg .= 'No data for profile file defined';
	$kiwi -> warning ($msg);
	$kiwi -> skipped ();
	return 1;
}

#==========================================
# Private helper methods
#------------------------------------------
#==========================================
# __updateXMLDrivers
#------------------------------------------
sub __updateXMLDrivers {
	my $this = shift;
	my $xml  = shift;
	my $drivers = $xml -> getDrivers();
	my @drvNames;
	for my $drv (@{$drivers}) {
		push @drvNames, $drv -> getName();
	}
	if (@drvNames) {
		my $addItem = join q{,}, @drvNames;
		$this -> addEntry('kiwi_drivers', $addItem);
	}
	return $this;
}

#==========================================
# __updateXMLSystemDisk
#------------------------------------------
sub __updateXMLSystemDisk {
	my $this = shift;
	my $xml  = shift;
	my $systemdisk = $xml -> getSystemDiskConfig();
	if ($systemdisk) {
		my $lvmgroup = $systemdisk -> getVGName();
		if ($lvmgroup) {
			$this -> addEntry('kiwi_lvmgroup',$lvmgroup);
		}
	}
	return $this;
}

#==========================================
# __updateXMLMachine
#------------------------------------------
sub __updateXMLMachine {
	my $this = shift;
	my $xml  = shift;
	my $vconf = $xml -> getVMachineConfig();
	if ($vconf) {
		my $domain = $vconf -> getDomain();
		if ($domain) {
			$this -> addEntry('kiwi_xendomain',$domain);
		}
	}
	return $this;
}

#==========================================
# __updateXMLOEMConfig
#------------------------------------------
sub __updateXMLOEMConfig {
	my $this = shift;
	my $xml  = shift; 
	my $oemconf = $xml -> getOEMConfig();
	my %oem;
	if ($oemconf) {
		$oem{kiwi_oemataraid_scan}       = $oemconf -> getAtaRaidScan();
		$oem{kiwi_oemswapMB}             = $oemconf -> getSwapSize();
		$oem{kiwi_oemrootMB}             = $oemconf -> getSystemSize();
		$oem{kiwi_oemswap}               = $oemconf -> getSwap();
		$oem{kiwi_oemalign}              = $oemconf -> getAlignPartition();
        $oem{kiwi_oempartition_install}  = $oemconf -> getPartitionInstall();
        $oem{kiwi_oemtitle}              = $oemconf -> getBootTitle();
        $oem{kiwi_oemkboot}              = $oemconf -> getKiwiInitrd();
        $oem{kiwi_oemreboot}             = $oemconf -> getReboot();
        $oem{kiwi_oemrebootinteractive}  = $oemconf -> getRebootInteractive();
        $oem{kiwi_oemshutdown}           = $oemconf -> getShutdown();
        $oem{kiwi_oemshutdowninteractive}= $oemconf -> getShutdownInteractive();
        $oem{kiwi_oemsilentboot}         = $oemconf -> getSilentBoot();
        $oem{kiwi_oemsilentinstall}      = $oemconf -> getSilentInstall();
        $oem{kiwi_oemsilentverify}       = $oemconf -> getSilentVerify();
        $oem{kiwi_oemskipverify}         = $oemconf -> getSkipVerify();
        $oem{kiwi_oembootwait}           = $oemconf -> getBootwait();
        $oem{kiwi_oemunattended}         = $oemconf -> getUnattended();
        $oem{kiwi_oemunattended_id}      = $oemconf -> getUnattendedID();
        $oem{kiwi_oemrecovery}           = $oemconf -> getRecovery();
        $oem{kiwi_oemrecoveryID}         = $oemconf -> getRecoveryID();
        $oem{kiwi_oemrecoveryInPlace}    = $oemconf -> getInplaceRecovery();
		#==========================================
		# special handling
		#------------------------------------------
		if ($oem{kiwi_oemswap} ne 'false') {
			$this -> addEntry('kiwi_oemswap','true');
			if (($oem{kiwi_oemswapMB}) && ($oem{kiwi_oemswapMB} > 0)) {
				$this -> addEntry('kiwi_oemswapMB',$oem{kiwi_oemswapMB});
			}
		}
		if (($oem{kiwi_oemataraid_scan}) && 
			($oem{kiwi_oemataraid_scan} eq 'false')
		) {
			$this -> addEntry(
				'kiwi_oemataraid_scan',$oem{kiwi_oemataraid_scan}
			);
		}
		if ($oem{kiwi_oemtitle}) {
			$this -> addEntry(
				'kiwi_oemtitle',$this -> __quote ($oem{kiwi_oemtitle})
			);
		}
		delete $oem{kiwi_oemtitle};
		delete $oem{kiwi_oemswap};
		delete $oem{kiwi_oemswapMB};
		delete $oem{kiwi_oemataraid_scan};
		#==========================================
		# default handling for non false values
		#------------------------------------------
		foreach my $key (keys %oem) {
			my $value = $oem{$key};
			next if ! $value;
			next if ($value eq 'false');
			$this -> addEntry ($key,$value);
		}
	}
	return $this;
}

#==========================================
# __storeRevisionInformation
#------------------------------------------
sub __storeRevisionInformation {
	my $this = shift;
	if (! $this->{profile}{kiwi_revision}) {
		my $rev   = "unknown";
		my $revFl = KIWIGlobals
			-> instance() -> getKiwiConfig() -> {Revision};
		my $FD = FileHandle -> new();
		if ($FD -> open ($revFl)) {
			$rev = <$FD>;
			$rev =~ s/\n//msxg;
			$FD -> close();
		}
		$this -> addEntry ("kiwi_revision",$rev);
	}
	return $this;
}

1;