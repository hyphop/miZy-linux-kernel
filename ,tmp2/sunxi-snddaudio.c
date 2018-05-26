
ssize_t set_attr_snddaudio1(struct class *class, struct class_attribute *attr,
			const char *buf, size_t size)
{

	int val;

	char *name = "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0";
	sprintf(name,"%s\0", attr[0] );

	if (!sscanf(buf, "%d\n", &val))
		return -EINVAL;
		
	DAUDIO_DBG("%s: %s <= %d\n", __func__, name, val);
		
	if			(!memcmp(name, "daudio_p", 8)) {
			daudio_pcm_select = val;
	} else if	(!memcmp(name, "daudio_m", 8)) {
			daudio_master = val;
	} else if	(!memcmp(name, "audio",5 )) {
			audio_format = val;
	} else if	(!memcmp(name, "sign", 4)) {
			signal_inversion = val;
	} else {
		DAUDIO_DBG("%s: unparsed (%s)\n", __func__, name);
	}
	return size;
}

ssize_t get_attr_snddaudio1(struct class *class, struct class_attribute *attr, char *buf)
{
	ssize_t outsize  ;

	int val;

	char *name = "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0";
	sprintf(name,"%s\0", attr[0] );

	if			(!memcmp(name, "daudio_p", 8)) {
			val = daudio_pcm_select;
	} else if	(!memcmp(name, "daudio_m", 8)) {
			val = daudio_master;
	} else if	(!memcmp(name, "audio",5 )) {
			val = audio_format;
	} else if	(!memcmp(name, "sign", 4)) {
			val = signal_inversion;
	} else {
		DAUDIO_DBG("%s: unparsed (%s)\n", __func__, name);
	}

		outsize = sprintf(buf,"%d\n", val );

		DAUDIO_DBG("%s: %s = %s", __func__, name, buf );

		return outsize;

}


// ## hyphop ##
static struct class_attribute daudio1_class_attrs[] = {
//	__ATTR(dump, 0644, dump_show, dump_store),

	__ATTR(daudio_pcm_select,	0644, get_attr_snddaudio1, set_attr_snddaudio1),
	__ATTR(daudio_master,		0644, get_attr_snddaudio1, set_attr_snddaudio1),
	__ATTR(audio_format,		0644, get_attr_snddaudio1, set_attr_snddaudio1),
	__ATTR(signal_inversion,	0644, get_attr_snddaudio1, set_attr_snddaudio1),
	__ATTR_NULL,
};

static struct class snddaudio1_class = {
    .name = "sunxi-snddaudio1",
    .owner = THIS_MODULE,
    .class_attrs = daudio1_class_attrs,
};


static int __init sunxi_snddaudio_init(void)
{
	int err = 0;
	script_item_u val;
	script_item_value_type_e  type;
	type = script_get_item(TDM_NAME, "daudio_used", &val);
	if (SCIRPT_ITEM_VALUE_TYPE_INT != type) {
        	pr_err("[daudio1]:%s,line:%d type err!\n", __func__, __LINE__);
    	}
	daudio_used = val.val;
	if (daudio_used) {
		if((err = platform_device_register(&sunxi_daudio_device)) < 0)
			return err;

		if ((err = platform_driver_register(&sunxi_daudio_driver)) < 0)
			return err;
	} else {
		pr_warning("[DAUDIO1] driver not init,just return.\n");
	}

// ## hyphop ## add

    int status;

    status = class_register(&snddaudio1_class);
    if (status < 0)
        pr_err("%s: status %d\n", __func__, status);
    else
        pr_info("%s success\n", __func__);

//    return status;

	return 0;
}
